/* kodiak_arm.cc -- the ARM side of Kodiak (the SPARCstation 20 SoC) on the
 * Ultra96-v2.
 *
 * The PL runs the superdupersparc core and the devices in RTL (SLAVIO misc,
 * counter/timers, interrupt controller, the ECC and IOMMU registers).  This
 * program runs every other device: ss10sim's sun4m C++ models (the ZS serial
 * ports, NVRAM, ESP + SCSI disks, Lance, TCX), served through the window
 * (rtl/arm_window.sv, win_service.h -- the same code kodiak_tb runs).
 *
 * DRAM (the 496 MB the kernel reserves, base = S00 write 0x06, mask = write 0x08):
 *   0x00000000  guest RAM (kodiak_soc's RAM_BYTES, 256 MB)
 *   0x1d000000  the boot PROM, 1 MB (OBP is loaded here)
 *   0x1e000000  the window's staging region (16 MB, to the end)
 *
 * DMA (ESP, Lance) translates DVMA on the ARM (sun4m_t::iommu_dma) with the
 * IOMMU's CTRL and BASE from the RTL, and reads and writes guest RAM directly;
 * each line is first snooped out of the core's caches (arm_snoop.sv), and a
 * written line again after, so DRAM and the caches agree. */
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>
#include <vector>
#include <fcntl.h>
#include <poll.h>
#include <termios.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <boost/program_options.hpp>
#include "driver.hh"
#include "interpret.hh"
#include "sparse_mem.hh"
#include "sun4m.hh"
#include "scsi.hh"
#include "tcx.hh"
#include "win_service.h"

namespace po = boost::program_options;

/* S00_AXI registers (Kodiak) */
enum {
  REG_CONTROL0 = 0x00, REG_CONTROL = 0x04, REG_RESUME_PC = 0x05, REG_BASE = 0x06, REG_MAGIC = 0x08,
  REG_MASK = 0x08, REG_SNOOP_SEQ = 0x0d, REG_SNOOP_LINE = 0x0f,
  REG_SNOOP_DONE = 0x30, REG_IOMMU_CTRL = 0x31, REG_IOMMU_BASE = 0x32, REG_SYS_RESETS = 0x33,
  /* debug readback */
  REG_STATUS = 0x03, REG_LAST_PC = 0x07, REG_LAST_ADDR = 0x09, REG_INSNS = 0x28,
  REG_WIN_HELD = 0x21,   /* {held load pending, its recno[30:0]} */
};
static const uint32_t CTRL_RESET = 1u << 0, CTRL_RESUME = 1u << 1;
static const uint32_t STATUS_READY = 1u << 0;   /* ready_for_resume */
static const uint32_t MAGIC = 0x7370696d;
static const uint64_t DRAM_SIZE = 496ULL << 20;    /* reserved by the kernel (as Henry's driver):
						    * never touch past it -- that is kernel memory */
static const uint64_t RAM_BYTES = 256ULL << 20;
static const uint64_t PROM_OFF = 0x1d000000ULL;

static Driver *g_d = nullptr;
static uint8_t *g_dram = nullptr;
static uint32_t g_snoop_seq = 0;
static uint64_t g_snoops = 0;
static uint64_t g_t0_ns = 0;
static win_svc_t g_win;

static uint64_t mono_ns() {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return static_cast<uint64_t>(ts.tv_sec) * 1000000000ULL + static_cast<uint64_t>(ts.tv_nsec);
}

/* the C++ models' clock: real time since the core started */
static uint64_t board_clock_ns(void *ctx) {
  (void)ctx;
  return mono_ns() - g_t0_ns;
}

static void doorbell(void *ctx, uint32_t reg, uint32_t v) {
  (void)ctx;
  g_d->write32(reg, v);
}

/* one line out of the core's caches (WBINV), so DRAM holds its latest data */
static void snoop_line(uint64_t line) {
  ring_wmb();
  g_d->write32(REG_SNOOP_LINE, static_cast<uint32_t>(line >> 4));
  g_d->write32(REG_SNOOP_SEQ, ++g_snoop_seq);
  while(g_d->read32(REG_SNOOP_DONE) != g_snoop_seq) {
    /* the L2 takes the snoop only while the core is not waiting on us: NACK a
     * held window load (win_service.h) */
    win_nack_held(&g_win, g_d->read32(REG_WIN_HELD));
  }
  ring_rmb();
  ++g_snoops;
}

static void dma_snoop(void *ctx, uint64_t pa, uint32_t len) {
  (void)ctx;
  for(uint64_t line = pa & ~15ULL; line < pa + len; line += 16) {
    snoop_line(line);
  }
}

static void iommu_from_rtl(sun4m_t *board);

/* the models behind the window */
struct board_ctx_t {
  sun4m_t *board;
  state_t *s;
};
static uint32_t win_read(void *ctx, uint64_t pa, uint32_t size, bool *bus_error) {
  board_ctx_t *b = static_cast<board_ctx_t*>(ctx);
  return b->board->read(b->s, pa, size, bus_error);
}
static void win_write(void *ctx, uint64_t pa, uint32_t size, uint32_t v, bool *bus_error) {
  board_ctx_t *b = static_cast<board_ctx_t*>(ctx);
  iommu_from_rtl(b->board);   /* a store can start a DMA */
  b->board->write(b->s, pa, size, v, bus_error);
}

/* the IOMMU registers live in RTL: the DMA translation reads them from there,
 * before anything that can start or continue a DMA (a store, a device event) */
static void iommu_from_rtl(sun4m_t *board) {
  board->iommu[0] = g_d->read32(REG_IOMMU_CTRL);
  board->iommu[1] = g_d->read32(REG_IOMMU_BASE);
}

/* the interrupt sources of the devices on the ARM (kodiak_tb's ext_irq) */
static uint32_t ext_irq(const sun4m_t *b) {
  return (b->kbd_ms.irq ? (1u << 14) : 0) | (b->serial.irq ? (1u << 15) : 0) |
    (b->fdc.irq ? (1u << 22) : 0) | (b->espdma.irq ? (1u << 18) : 0) |
    (b->ledma.irq ? (1u << 16) : 0);
}

/* --scsi-disk / --scsi-cdrom "[ID:]image", as ss10sim's */
static bool attach_scsi(sun4m_t *m, const std::vector<std::string> &specs, scsi_dev_t::type_t t,
			uint32_t first_id) {
  uint32_t next = first_id;
  for(const std::string &spec : specs) {
    uint32_t id;
    std::string path = spec;
    if(spec.size() > 2 and spec[1] == ':' and spec[0] >= '0' and spec[0] <= '6') {
      id = spec[0] - '0';
      path = spec.substr(2);
    }
    else {
      while(next < 7 and m->scsi[next] != nullptr) {
	next++;
      }
      id = next;
    }
    if(id >= 7 or m->scsi[id] != nullptr) {
      fprintf(stderr, "scsi: no free target ID for '%s'\n", spec.c_str());
      return false;
    }
    scsi_dev_t *d = new scsi_dev_t(t, path);
    if(not d->ok()) {
      delete d;
      return false;
    }
    m->scsi[id] = d;
    fprintf(stderr, "scsi: target %u: %s\n", id, path.c_str());
  }
  return true;
}

int main(int argc, char *argv[]) {
  std::string rom, nvram, tcx_rom;
  std::vector<std::string> scsi_disks, scsi_cdroms;
  uint64_t control = 0xa0050000ULL;   /* the BD address of the axi_is_the_worst slave */
  bool no_kbd = false;
  try {
    po::options_description desc("Options");
    desc.add_options()
      ("help", "Print help messages")
      ("rom,r", po::value<std::string>(&rom)->required(), "SS-20 boot PROM image (OBP 2.25R)")
      ("nvram", po::value<std::string>(&nvram), "M48T08 NVRAM image")
      ("tcx", po::value<std::string>(&tcx_rom), "a TCX framebuffer, with this FCode PROM")
      ("no-kbd", po::bool_switch(&no_kbd), "no keyboard: the console is ttya")
      ("scsi-disk", po::value<std::vector<std::string>>(&scsi_disks), "[ID:]image: a SCSI disk")
      ("scsi-cdrom", po::value<std::vector<std::string>>(&scsi_cdroms), "[ID:]image: a SCSI CD-ROM")
      ("control", po::value<uint64_t>(&control), "physical address of the S00_AXI registers")
      ;
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    if(vm.count("help")) {
      std::cout << desc << "\n";
      return 0;
    }
    po::notify(vm);
  }
  catch(po::error &e) {
    std::cerr << "command-line error : " << e.what() << "\n";
    return -1;
  }

  /* the board: as ss10sim's sun4m power-on */
  sun4m_t *board = new sun4m_t();
  if(not board->load_prom(rom.c_str())) {
    return 1;
  }
  if(not nvram.empty() and not board->load_nvram(nvram.c_str())) {
    return 1;
  }
  if(not tcx_rom.empty()) {
    board->tcx = new tcx_t();
    if(not board->tcx->load_rom(tcx_rom)) {
      fprintf(stderr, "kodiak_arm: cannot read the TCX FCode %s\n", tcx_rom.c_str());
      return 1;
    }
    board->have_kbd = not no_kbd;
    board->reset_devices(0);
  }
  if(not attach_scsi(board, scsi_disks, scsi_dev_t::type_t::disk, 0) or
     not attach_scsi(board, scsi_cdroms, scsi_dev_t::type_t::cdrom, 6)) {
    return 1;
  }

  /* the reserved DRAM and the PL's registers */
  uint64_t phys_addr = 0;
  int fd = open("/dev/rv64core_fpga", O_RDWR | O_SYNC);
  if(fd < 0 or ioctl(fd, 0, &phys_addr) < 0) {
    fprintf(stderr, "kodiak_arm: cannot get the FPGA memory region\n");
    return 1;
  }
  close(fd);
  g_d = new Driver(control);
  if(g_d->read32(REG_MAGIC) != MAGIC) {
    fprintf(stderr, "kodiak_arm: no core at 0x%llx\n", static_cast<unsigned long long>(control));
    return 1;
  }
  fd = open("/dev/mem", O_RDWR | O_SYNC);
  if(fd < 0) {
    perror("/dev/mem");
    return 1;
  }
  void *v = mmap(nullptr, DRAM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, phys_addr);
  if(v == MAP_FAILED) {
    perror("mmap");
    return 1;
  }
  g_dram = static_cast<uint8_t*>(v);
  memset(g_dram, 0, DRAM_SIZE);
  memcpy(g_dram + PROM_OFF, board->prom, SUN4M_PROM_SIZE);
  printf("kodiak_arm: DRAM at 0x%llx, OBP loaded\n", static_cast<unsigned long long>(phys_addr));

  /* the models' view of guest RAM: the DRAM itself */
  sparse_mem *mem = new sparse_mem();
  munmap(mem->mem, sparse_mem::sz);
  mem->mem = g_dram;
  state_t *s = new state_t(*mem);
  s->ram_size = RAM_BYTES;
  s->sun4m = board;
  board->clock_ns = board_clock_ns;
  board->dma_snoop = dma_snoop;

  board_ctx_t bctx = {board, s};
  win_svc_t &win = g_win;
  ring_io_t io;
  io.stg = g_dram + RING_STG_PA;
  io.doorbell = doorbell;
  io.ctx = nullptr;
  win_dev_t dev;
  dev.ctx = &bctx;
  dev.read = win_read;
  dev.write = win_write;
  win_init(&win, io, dev);

  /* reset the PL (core, window, snoop doorbell), then run from the PROM */
  g_d->write32(REG_BASE, static_cast<uint32_t>(phys_addr));
  g_d->write32(REG_MASK, static_cast<uint32_t>(DRAM_SIZE - 1));
  g_d->write32(REG_CONTROL0, 0);
  for(uint32_t r : {(uint32_t)WIN_DB_ANS_LO, (uint32_t)WIN_DB_ANS_HI, (uint32_t)WIN_DB_ANS_SEQ,
		    (uint32_t)WIN_DB_CONS, (uint32_t)WIN_DB_IRQ, (uint32_t)REG_SNOOP_SEQ}) {
    g_d->write32(r, 0);
  }
  /* hold reset well past the core's per-cycle register-file seeding (kodiak_tb
   * holds it >= 256 cycles), then wait for the core to finish its reset flush */
  g_d->write32(REG_RESUME_PC, 0);
  g_d->write32(REG_CONTROL, CTRL_RESET);
  usleep(10000);
  g_d->write32(REG_CONTROL, 0);
  for(int i = 0; (i < 1000) and not (g_d->read32(REG_STATUS) & STATUS_READY); i++) {
    usleep(1000);
  }
  if(not (g_d->read32(REG_STATUS) & STATUS_READY)) {
    fprintf(stderr, "kodiak_arm: the core is not ready after reset (status 0x%08x)\n", g_d->read32(REG_STATUS));
    return 1;
  }
  uint32_t sys_resets = g_d->read32(REG_SYS_RESETS);
  g_t0_ns = mono_ns();
  g_d->write32(REG_CONTROL, CTRL_RESUME);
  usleep(100000);
  printf("kodiak_arm: running: status 0x%08x, %u insns, last pc 0x%08x, last AXI addr 0x%08x\n",
	 g_d->read32(REG_STATUS), g_d->read32(REG_INSNS), g_d->read32(REG_LAST_PC), g_d->read32(REG_LAST_ADDR));
  fflush(stdout);

  /* the console: stdin raw, a byte into ttya whenever it can take one */
  struct termios old_tio, tio;
  const bool tty = (tcgetattr(0, &old_tio) == 0);
  if(tty) {
    tio = old_tio;
    tio.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(0, TCSANOW, &tio);
  }
  uint32_t irq = 0;
  uint64_t iter = 0;
  for(;;) {
    /* the window, a batch at a time */
    for(int i = 0; i < 64; i++) {
      if(not win_service_one(&win)) {
	break;
      }
    }
    if(win.bad_recno != 0) {
      fprintf(stderr, "kodiak_arm: a bad window record, stopping\n");
      break;
    }
    if(board->now_ns(s) >= board->next_event_ns) {
      iommu_from_rtl(board);
      board->timer_event(s);
    }
    if((++iter & 255) == 0) {
      /* a system reset by the RTL's sequencer: the devices here reset too */
      const uint32_t n = g_d->read32(REG_SYS_RESETS);
      if(n != sys_resets) {
	sys_resets = n;
	board->reset_devices(board->now_ns(s));
	board->reset_req = false;
	printf("\nkodiak_arm: system reset\n");
      }
      struct pollfd pfd = {0, POLLIN, 0};
      if(board->serial.can_receive(1) and poll(&pfd, 1, 0) > 0) {
	uint8_t ch;
	if(read(0, &ch, 1) == 1) {
	  board->serial.receive(1, (ch == '\n') ? '\r' : ch);
	  board->update_irqs(s);
	}
      }
    }
    const uint32_t ni = ext_irq(board);
    if(ni != irq) {
      irq = ni;
      g_d->write32(WIN_DB_IRQ, irq);
    }
  }
  if(tty) {
    tcsetattr(0, TCSANOW, &old_tio);
  }
  printf("kodiak_arm: %llu NACKs, %llu NACKed records dropped\n", static_cast<unsigned long long>(win.nacks),
	 static_cast<unsigned long long>(win.skipped));
  printf("kodiak_arm: %llu records (%llu stores, %llu reads, %llu atomics, %llu bus errors), %llu snoops\n",
	 static_cast<unsigned long long>(win.cons), static_cast<unsigned long long>(win.stores),
	 static_cast<unsigned long long>(win.reads), static_cast<unsigned long long>(win.atomics),
	 static_cast<unsigned long long>(win.bus_errors), static_cast<unsigned long long>(g_snoops));
  return 0;
}
