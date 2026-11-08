#ifndef __WIN_SERVICE_H__
#define __WIN_SERVICE_H__
/* ARM side of Kodiak's ARM-served device window (rtl/arm_window.sv).
 *
 * ONE source for both the board program and kodiak_tb (as Henry's gio_service.h),
 * so co-simulation runs exactly the code the ARM runs.  The PL turns every CPU
 * access to a device not in RTL into a 16-byte record in the capture ring; this
 * drains the ring in order into the device models (ss10sim's sun4m C++) and
 * answers READ/ATOMIC records, which the PL holds the CPU for.
 *
 * Record (LE): [20:0] recno[20:0] (records are numbered 1, 2, 3, ...), [53:21]
 * pa[35:3] (the doubleword), [61:54] byte mask (lane i = the byte at pa + i),
 * [63:62] type (0 STORE, 1 READ, 2 ATOMIC: read, answer, then store), [127:64]
 * lanes 0-7 (store data).  Record n lives in slot (n-1) mod WIN_N; prod (records
 * written) is at staging +WIN_PROD; cons is ours, doorbelled after each record.
 * The answer: WIN_DB_ANS_LO = lanes 0-3, WIN_DB_ANS_HI = lanes 4-7, then
 * WIN_DB_ANS_SEQ = {bus error, retry, 9'd0, recno[20:0]}.
 *
 * NACK (retry): while the core waits for a held READ/ATOMIC, its L2 cannot take
 * a snoop, so a DMA that must snoop (dma_snoop) would wait for the core while
 * the core waits for us.  The snoop's wait loop calls win_nack_held(): the held
 * load is answered "retry" (no data), the L2 serves the snoop and then re-issues
 * the load as a new record; the NACKed record is dropped unperformed when the
 * ring reaches it, so a read with side effects happens once.
 *
 * The models see big-endian accesses: each run of masked bytes is split into
 * accesses of at most 4 bytes (a 3-byte piece as 2 + 1), value = the bytes in
 * address order, most significant first. */
#include <algorithm>
#include <cstdint>
#include "ring_service.h"

enum {
  WIN_DB_ANS_LO = 0x20, WIN_DB_ANS_HI = 0x21, WIN_DB_ANS_SEQ = 0x22, WIN_DB_CONS = 0x23,
  WIN_DB_IRQ = 0x2a,
};
static const uint32_t WIN_RING = 0x200000;   /* staging offset of the capture ring */
static const uint32_t WIN_N    = 65536;
static const uint32_t WIN_PROD = 0x00060;

struct win_dev_t {
  void *ctx;
  uint32_t (*read)(void *ctx, uint64_t pa, uint32_t size, bool *bus_error);
  void (*write)(void *ctx, uint64_t pa, uint32_t size, uint32_t v, bool *bus_error);
};

static const uint32_t WIN_ANS_RETRY = 1u << 30, WIN_ANS_BAD = 1u << 31;

struct win_svc_t {
  ring_io_t io;
  win_dev_t dev;
  uint32_t cons;             /* ARM-owned: records consumed */
  uint32_t cur;              /* recno[20:0] of the record being served, 0 none */
  /* NACKed recnos[20:0] not yet reached in the ring, oldest first: a DMA NACKs
   * once per line it snoops (the core re-issues its load in between), all before
   * the ring is drained again; they are increasing and the ring is drained in
   * order, so a FIFO the size of the ring holds them */
  uint32_t nackq[WIN_N];
  uint32_t nq_head, nq_tail;
  uint64_t stores, reads, atomics, bus_errors, bad_recno, nacks, skipped;
};

/* held = the PL's held-load register, {pending, recno[30:0]} (S00 read 0x21):
 * NACK that load, unless it is the record being served (that one we answer) */
static inline void win_nack_held(win_svc_t *w, uint32_t held) {
  if(not (held >> 31)) {
    return;
  }
  const uint32_t recno = held & 0x1fffff;
  if(recno == w->cur) {
    return;
  }
  if((w->nq_tail != w->nq_head) and (w->nackq[(w->nq_tail - 1) & (WIN_N - 1)] == recno)) {
    return;   /* already NACKed (the PL clears its held flag a cycle later) */
  }
  if(w->nq_tail - w->nq_head == WIN_N) {
    fprintf(stderr, "win: NACK queue full\n");
    ++w->bad_recno;
    return;
  }
  w->nackq[w->nq_tail++ & (WIN_N - 1)] = recno;
  w->io.doorbell(w->io.ctx, WIN_DB_ANS_SEQ, recno | WIN_ANS_RETRY);
  ++w->nacks;
}

static inline void win_init(win_svc_t *w, ring_io_t io, win_dev_t dev) {
  memset(w, 0, sizeof(*w));
  w->io = io;
  w->dev = dev;
}

/* the accesses of one record: a read fills lanes[], a write takes them */
static inline void win_access(win_svc_t *w, bool store, uint64_t dw, uint32_t mask, uint8_t lanes[8],
			      bool *bus_error) {
  int k = 0;
  while(k < 8) {
    if(not ((mask >> k) & 1)) {
      ++k;
      continue;
    }
    int e = k;
    while(e < 8 and ((mask >> e) & 1)) {
      ++e;
    }
    for(int a = k; a < e; ) {
      uint32_t size = static_cast<uint32_t>(std::min(e - a, 4));
      if(size == 3) {
	size = 2;
      }
      if(store) {
	uint32_t v = 0;
	for(uint32_t b = 0; b < size; b++) {
	  v = (v << 8) | lanes[a + b];
	}
	w->dev.write(w->dev.ctx, dw + a, size, v, bus_error);
      }
      else {
	const uint32_t v = w->dev.read(w->dev.ctx, dw + a, size, bus_error);
	for(uint32_t b = 0; b < size; b++) {
	  lanes[a + b] = static_cast<uint8_t>(v >> (8 * (size - 1 - b)));
	}
      }
      a += size;
    }
    k = e;
  }
}

/* serve the next record, if one is published; false when the ring is empty */
static inline bool win_service_one(win_svc_t *w) {
  const uint32_t prod = ring_rd32(w->io, WIN_PROD);
  if(prod == w->cons) {
    return false;
  }
  ring_rmb();
  const uint32_t rec = WIN_RING + 16 * (w->cons & (WIN_N - 1));
  const uint64_t h = static_cast<uint64_t>(ring_rd32(w->io, rec)) |
    (static_cast<uint64_t>(ring_rd32(w->io, rec + 4)) << 32);
  uint8_t lanes[8];
  for(int i = 0; i < 8; i++) {
    lanes[i] = w->io.stg[rec + 8 + i];
  }
  const uint32_t recno = static_cast<uint32_t>(h & 0x1fffff);
  const uint64_t dw = ((h >> 21) & ((1ULL << 33) - 1)) << 3;
  const uint32_t mask = static_cast<uint32_t>((h >> 54) & 0xff);
  const uint32_t type = static_cast<uint32_t>(h >> 62);
  if(recno != ((w->cons + 1) & 0x1fffff) or type == 3) {
    fprintf(stderr, "win: bad record %016llx in slot %u (expected recno %u)\n",
	    static_cast<unsigned long long>(h), w->cons & (WIN_N - 1), (w->cons + 1) & 0x1fffff);
    ++w->bad_recno;
  }
  if((w->nq_tail != w->nq_head) and (w->nackq[w->nq_head & (WIN_N - 1)] == recno)) {
    /* NACKed: the core re-issued it as a later record */
    ++w->nq_head;
    ++w->skipped;
    ++w->cons;
    w->io.doorbell(w->io.ctx, WIN_DB_CONS, w->cons);
    return true;
  }
  w->cur = recno;
  bool be = false;
  if(type == 0) {
    win_access(w, true, dw, mask, lanes, &be);
    ++w->stores;
  }
  else {
    uint8_t old[8] = {0, 0, 0, 0, 0, 0, 0, 0};
    win_access(w, false, dw, mask, old, &be);
    if(type == 2 and not be) {
      win_access(w, true, dw, mask, lanes, &be);
      ++w->atomics;
    }
    else {
      ++w->reads;
    }
    uint32_t lo = 0, hi = 0;
    for(int i = 0; i < 4; i++) {
      lo |= static_cast<uint32_t>(old[i]) << (8 * i);
      hi |= static_cast<uint32_t>(old[4 + i]) << (8 * i);
    }
    w->io.doorbell(w->io.ctx, WIN_DB_ANS_LO, lo);
    w->io.doorbell(w->io.ctx, WIN_DB_ANS_HI, hi);
    w->io.doorbell(w->io.ctx, WIN_DB_ANS_SEQ, recno | (be ? WIN_ANS_BAD : 0));
  }
  w->cur = 0;
  if(be) {
    ++w->bus_errors;
  }
  ++w->cons;
  w->io.doorbell(w->io.ctx, WIN_DB_CONS, w->cons);
  return true;
}

#endif
