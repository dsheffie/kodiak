// -----------------------------------------------------------------------------
// kodiak_soc.sv -- Kodiak, the wannabe SPARCstation 20 (sun4m) SoC: top level.
//
// Wraps the superdupersparc core (core_l1d_l1i, the superdupersparc submodule).
// The core's 16-byte line bus goes through a physical-address decode, as in
// henry_soc: a request for an RTL device is answered here; RAM and the boot
// PROM pass through on the external memory bus; every other device goes to
// the ARM-served window (arm_window.sv), where ss10sim's C++ sun4m models
// answer it -- on the ARM on the FPGA, in the testbench in co-sim.  The SS-20
// devices move into RTL one at a time, re-targeted from Henry's (the IP22 SoC
// this repo was forked from).
//
// The ports are the core's, under the same names, so the co-sim testbench (a
// copy of superdupersparc's top.cc) drives the SoC as it drove the bare core,
// plus a sim-only tap of the accesses the RTL devices answer.
// -----------------------------------------------------------------------------
`include "machine.vh"

module kodiak_soc #(parameter logic [35:0] RAM_BYTES = 36'h10000000)   /* installed RAM: 256 MB */
  (clk,
		  reset,
		  retire_allowed,
		  single_step,
		  bp_enable,
		  fault_clear,
		  bp_pc,
		  bp_wp_addr,
		  bp_wp_val,
		  bp_fault_only,
		  rt_oneshot,
		  l2_nocache,
		  step,
		  in_flush_mode,
		  resume,
		  resume_pc,
		  ready_for_resume,
		  mem_req_valid,
		  mem_req_addr,
		  mem_req_store_data,
		  mem_req_opcode,
		  mem_req_mask,
		  mem_req_uncached,
		  mem_rsp_valid,
		  mem_rsp_bad,
		  mem_rsp_load_data,
		  retire_fp_reg_ptr,
		  retire_fp_reg_data,
		  retire_fp_reg_valid,
		  retire_fp_reg_two_ptr,
		  retire_fp_reg_two_data,
		  retire_fp_reg_two_valid,
		  retire_fcr_reg_ptr,
		  retire_fcr_reg_data,
		  retire_fcr_reg_valid,
		  retire_fcr_reg_two_ptr,
		  retire_fcr_reg_two_data,
		  retire_fcr_reg_two_valid,
		  retire_load_addr,
		  retire_load_addr_two,
		  wf_epc,
		  wf_badv,
		  wf_stat,
		  retire_reg_ptr,
		  retire_reg_data,
		  retire_reg_valid,
		  retire_reg_two_ptr,
		  retire_reg_two_data,
		  retire_reg_two_valid,
		  retire_y_valid,
		  retire_y_data,
		  retire_valid,
		  retire_two_valid,
		  retire_pc,
		  retire_two_pc,
`ifdef VERILATOR
		  retire_insn,
		  retire_two_insn,
		  dev_tap_valid,
		  dev_tap_addr,
		  dev_tap_mask,
		  dev_tap_opcode,
		  dev_tap_store_data,
		  dev_tap_load_data,
		  sim_cycle,
		  sim_irl,
		  sim_sys_reset,
`endif
		  retire_op,
		  retire_two_op,
		  branch_pc,
		  branch_pc_valid,
		  branch_fault,
		  l1i_cache_accesses,
		  l1i_cache_hits,
		  l1d_cache_accesses,
		  l1d_cache_hits,
		  l2_cache_accesses,
		  l2_cache_hits,
		  got_break,
		  ext_irq,
		  trap_taken,
		  trap_taken_tt,
		  trap_taken_pc,
		  got_ud,
		  got_bad_addr,
		  core_state,
		  l1i_state,
		  l1d_state,
		  l2_state,
		  l2_rsp_state,
		  inflight,
		  dbg_rob_inflight,
		  epc,
		  dbg_frozen,
		  dbg_wp_data,
		  l1i_flush_done,
		  l1d_flush_done,
		  l2_flush_done,
		  ext_flush_req,
		  ext_flush_done,
		  ext_flush_ppn,
		  ext_flush_whole,
		  ext_flush_drop,
		  ext_flush_dirty_cnt,
		  dbg_flush,
		  dma_inval_req,
		  dma_inval_addr,
		  dma_inval_ack,
		  snoop_req_valid,
		  snoop_req_addr,
		  snoop_req_ack,
		  snoop_req_wbinv,
		  snoop_done,
		  mem2_req_valid,
		  mem2_req_addr,
		  mem2_req_opcode,
		  mem2_req_store_data,
		  mem2_req_mask,
		  mem2_rsp_valid,
		  win_cons,
		  win_ans_lo,
		  win_ans_hi,
		  win_ans_seq,
		  win_prod,
		  win_pend,
		  win_pend_seq,
		  iommu_ctrl,
		  iommu_base,
		  sys_reset_cnt,
		  sys_reset_ack,
		  dbg_head_pc,
		  dbg_head_status,
		  dbg_head_fetch_cycle,
		  dbg_head_alloc_cycle,
		  dbg_serialize_cycle,
		  dbg_cycle,
		  dbg_oldest_first_pending,
		  dbg_trace_index,
		  dbg_trace_data,
		  dbg_trace_wptr);
   input logic clk;
   input logic reset;
   input logic retire_allowed;
   input logic single_step;
   input logic bp_enable;
   input logic fault_clear;
   input logic [31:0] bp_pc;
   input logic [31:0] bp_wp_addr;
   input logic [31:0] bp_wp_val;
   input logic bp_fault_only;
   input logic rt_oneshot;
   input logic l2_nocache;
   input logic step;
   output logic in_flush_mode;
   input logic resume;
   input logic [(`M_WIDTH-1):0] resume_pc;
   output logic ready_for_resume;
   output logic mem_req_valid;
   output logic [`PA_WIDTH-1:0] mem_req_addr;
   output logic [127:0] mem_req_store_data;
   output logic [4:0] mem_req_opcode;
   output logic [15:0] mem_req_mask;
   output logic mem_req_uncached;
   input logic mem_rsp_valid;
   input logic mem_rsp_bad;
   input logic [127:0] mem_rsp_load_data;
   output logic [4:0] retire_fp_reg_ptr;
   output logic [`FP_WIDTH-1:0] retire_fp_reg_data;
   output logic retire_fp_reg_valid;
   output logic [4:0] retire_fp_reg_two_ptr;
   output logic [`FP_WIDTH-1:0] retire_fp_reg_two_data;
   output logic retire_fp_reg_two_valid;
   output logic [4:0] retire_fcr_reg_ptr;
   output logic [`M_WIDTH-1:0] retire_fcr_reg_data;
   output logic retire_fcr_reg_valid;
   output logic [4:0] retire_fcr_reg_two_ptr;
   output logic [`M_WIDTH-1:0] retire_fcr_reg_two_data;
   output logic retire_fcr_reg_two_valid;
   output logic [31:0] retire_load_addr;
   output logic [31:0] retire_load_addr_two;
   output logic [31:0] wf_epc;
   output logic [31:0] wf_badv;
   output logic [31:0] wf_stat;
   output logic [`LG_PRF_ENTRIES-1:0] retire_reg_ptr;
   output logic [`M_WIDTH-1:0] retire_reg_data;
   output logic retire_reg_valid;
   output logic [`LG_PRF_ENTRIES-1:0] retire_reg_two_ptr;
   output logic [`M_WIDTH-1:0] retire_reg_two_data;
   output logic retire_reg_two_valid;
   output logic retire_y_valid;
   output logic [31:0] retire_y_data;
   output logic retire_valid;
   output logic retire_two_valid;
   output logic [(`M_WIDTH-1):0] retire_pc;
   output logic [(`M_WIDTH-1):0] retire_two_pc;
`ifdef VERILATOR
   output logic [31:0] retire_insn;
   output logic [31:0] retire_two_insn;
   /* sim only: one pulse per access an RTL device takes, in the cycle it takes
    * it (the co-sim checker replays the load data, and checks it and the store
    * against its C++ model at that cycle's time) */
   output logic dev_tap_valid;
   output logic [`PA_WIDTH-1:0] dev_tap_addr;
   output logic [15:0] dev_tap_mask;
   output logic [4:0] dev_tap_opcode;
   output logic [127:0] dev_tap_store_data;
   output logic [127:0] dev_tap_load_data;
   output logic [63:0] sim_cycle;          /* cycles since reset: the C++ models' clock */
   output logic [3:0] sim_irl;             /* the core's interrupt request level */
   output logic sim_sys_reset;             /* the system reset's device-reset cycle */
`endif
   output logic [8:0] retire_op;
   output logic [8:0] retire_two_op;
   output logic [(`M_WIDTH-1):0] branch_pc;
   output logic branch_pc_valid;
   output logic branch_fault;
   output logic [63:0] l1i_cache_accesses;
   output logic [63:0] l1i_cache_hits;
   output logic [63:0] l1d_cache_accesses;
   output logic [63:0] l1d_cache_hits;
   output logic [63:0] l2_cache_accesses;
   output logic [63:0] l2_cache_hits;
   output logic got_break;
   /* interrupt sources of the devices still outside the SoC (the testbench's
    * C++ models), by SLAVIO master pending bit */
   input logic [31:0] ext_irq;
   output logic trap_taken;
   output logic [7:0] trap_taken_tt;
   output logic [31:0] trap_taken_pc;
   output logic got_ud;
   output logic got_bad_addr;
   output logic [4:0] core_state;
   output logic [3:0] l1i_state;
   output logic [3:0] l1d_state;
   output logic [3:0] l2_state;
   output logic [3:0] l2_rsp_state;
   output logic [`LG_ROB_ENTRIES:0] inflight;
   output logic [31:0] dbg_rob_inflight;
   output logic [`M_WIDTH-1:0] epc;
   output logic [2:0] dbg_frozen;
   output logic [31:0] dbg_wp_data;
   output logic l1i_flush_done;
   output logic l1d_flush_done;
   output logic l2_flush_done;
   input logic ext_flush_req;
   output logic ext_flush_done;
   input logic [`PA_WIDTH-1:`LG_PG_SZ] ext_flush_ppn;
   input logic ext_flush_whole;
   input logic ext_flush_drop;
   output logic [15:0] ext_flush_dirty_cnt;
   output logic [31:0] dbg_flush;
   input logic dma_inval_req;
   input logic [`PA_WIDTH-1:0] dma_inval_addr;
   output logic dma_inval_ack;
   input logic snoop_req_valid;
   input logic [`PA_WIDTH-1:0] snoop_req_addr;
   output logic snoop_req_ack;
   input logic snoop_req_wbinv;
   output logic snoop_done;
   /* the ARM-served window's ring writes (to the staging region) and its doorbells */
   output logic mem2_req_valid;
   output logic [`PA_WIDTH-1:0] mem2_req_addr;
   output logic [4:0] mem2_req_opcode;
   output logic [511:0] mem2_req_store_data;
   output logic [15:0] mem2_req_mask;
   input logic mem2_rsp_valid;
   input logic [31:0] win_cons;
   input logic [31:0] win_ans_lo;
   input logic [31:0] win_ans_hi;
   input logic [31:0] win_ans_seq;
   output logic [31:0] win_prod;
   output logic win_pend;
   output logic [31:0] win_pend_seq;
   output logic [31:0] iommu_ctrl;
   output logic [31:0] iommu_base;
   /* system resets performed (the ARM resets its device models when it changes) */
   output logic [31:0] sys_reset_cnt;
   /* the ARM's acknowledgement: the sys_reset_cnt it has reset its device models
    * for (the core stays in reset until it matches) */
   input logic [31:0] sys_reset_ack;
   output logic [31:0] dbg_head_pc;
   output logic [31:0] dbg_head_status;
   output logic [31:0] dbg_head_fetch_cycle;
   output logic [31:0] dbg_head_alloc_cycle;
   output logic [31:0] dbg_serialize_cycle;
   output logic [31:0] dbg_cycle;
   output logic dbg_oldest_first_pending;
   input logic [19:0] dbg_trace_index;
   output logic [31:0] dbg_trace_data;
   output logic [15:0] dbg_trace_wptr;

   /* the system-reset sequencer's controls (below) */
   typedef enum logic [2:0] {
      SR_IDLE,
      SR_FLUSH_REQ,
      SR_FLUSH_WAIT,
      SR_DRAIN,
      SR_RESET,
      SR_RESUME_WAIT,
      SR_RESUME
   } sr_state_t;
   sr_state_t r_sr_state;
   sr_state_t n_sr_state;
   logic [12:0] r_sr_cnt;
   logic [12:0] n_sr_cnt;
   wire w_sys_reset_req;
   wire w_sr_flush = (r_sr_state == SR_FLUSH_REQ);
   wire w_sr_hold = (r_sr_state == SR_DRAIN) | (r_sr_state == SR_RESET) |
		    (r_sr_state == SR_RESUME_WAIT) | (r_sr_state == SR_RESUME);
   wire w_sr_core_reset = (r_sr_state == SR_RESET);
   /* the devices reset once, in the first cycle of the core's reset */
   wire w_sr_dev_reset = (r_sr_state == SR_RESET) & (r_sr_cnt == 13'd0);
   wire w_core_flush_done;

   /* the core's memory bus, ahead of the device decode */
   logic c_rsp_retry;
   logic c_req_valid;
   logic [`PA_WIDTH-1:0] c_req_addr;
   logic [127:0] c_req_store_data;
   logic [4:0] c_req_opcode;
   logic [15:0] c_req_mask;
   logic c_req_uncached;
   logic c_rsp_valid;
   logic c_rsp_bad;
   logic [127:0] c_rsp_load_data;
   wire [3:0] w_irl;

   core_l1d_l1i cpu
     (
      .clk(clk),
      .reset(reset),
      .sys_reset(w_sr_core_reset),
      .retire_allowed(retire_allowed & !w_sr_hold),
      .single_step(single_step),
      .bp_enable(bp_enable),
      .fault_clear(fault_clear),
      .bp_pc(bp_pc),
      .bp_wp_addr(bp_wp_addr),
      .bp_wp_val(bp_wp_val),
      .bp_fault_only(bp_fault_only),
      .rt_oneshot(rt_oneshot),
      .l2_nocache(l2_nocache),
      .step(step),
      .in_flush_mode(in_flush_mode),
      .resume(resume | (r_sr_state == SR_RESUME)),
      .resume_pc((r_sr_state == SR_RESUME) ? `M_WIDTH'(0) : resume_pc),
      .ready_for_resume(ready_for_resume),
      .mem_req_valid(c_req_valid),
      .mem_req_addr(c_req_addr),
      .mem_req_store_data(c_req_store_data),
      .mem_req_opcode(c_req_opcode),
      .mem_req_mask(c_req_mask),
      .mem_req_uncached(c_req_uncached),
      .mem_rsp_valid(c_rsp_valid),
      .mem_rsp_bad(c_rsp_bad),
      .mem_rsp_retry(c_rsp_retry),
      .mem_rsp_load_data(c_rsp_load_data),
      .retire_fp_reg_ptr(retire_fp_reg_ptr),
      .retire_fp_reg_data(retire_fp_reg_data),
      .retire_fp_reg_valid(retire_fp_reg_valid),
      .retire_fp_reg_two_ptr(retire_fp_reg_two_ptr),
      .retire_fp_reg_two_data(retire_fp_reg_two_data),
      .retire_fp_reg_two_valid(retire_fp_reg_two_valid),
      .retire_fcr_reg_ptr(retire_fcr_reg_ptr),
      .retire_fcr_reg_data(retire_fcr_reg_data),
      .retire_fcr_reg_valid(retire_fcr_reg_valid),
      .retire_fcr_reg_two_ptr(retire_fcr_reg_two_ptr),
      .retire_fcr_reg_two_data(retire_fcr_reg_two_data),
      .retire_fcr_reg_two_valid(retire_fcr_reg_two_valid),
      .retire_load_addr(retire_load_addr),
      .retire_load_addr_two(retire_load_addr_two),
      .wf_epc(wf_epc),
      .wf_badv(wf_badv),
      .wf_stat(wf_stat),
      .retire_reg_ptr(retire_reg_ptr),
      .retire_reg_data(retire_reg_data),
      .retire_reg_valid(retire_reg_valid),
      .retire_reg_two_ptr(retire_reg_two_ptr),
      .retire_reg_two_data(retire_reg_two_data),
      .retire_reg_two_valid(retire_reg_two_valid),
      .retire_y_valid(retire_y_valid),
      .retire_y_data(retire_y_data),
      .retire_valid(retire_valid),
      .retire_two_valid(retire_two_valid),
      .retire_pc(retire_pc),
      .retire_two_pc(retire_two_pc),
`ifdef VERILATOR
      .retire_insn(retire_insn),
      .retire_two_insn(retire_two_insn),
`endif
      .retire_op(retire_op),
      .retire_two_op(retire_two_op),
      .branch_pc(branch_pc),
      .branch_pc_valid(branch_pc_valid),
      .branch_fault(branch_fault),
      .l1i_cache_accesses(l1i_cache_accesses),
      .l1i_cache_hits(l1i_cache_hits),
      .l1d_cache_accesses(l1d_cache_accesses),
      .l1d_cache_hits(l1d_cache_hits),
      .l2_cache_accesses(l2_cache_accesses),
      .l2_cache_hits(l2_cache_hits),
      .got_break(got_break),
      .irl(w_irl),
      .trap_taken(trap_taken),
      .trap_taken_tt(trap_taken_tt),
      .trap_taken_pc(trap_taken_pc),
      .got_ud(got_ud),
      .got_bad_addr(got_bad_addr),
      .core_state(core_state),
      .l1i_state(l1i_state),
      .l1d_state(l1d_state),
      .l2_state(l2_state),
      .l2_rsp_state(l2_rsp_state),
      .inflight(inflight),
      .dbg_rob_inflight(dbg_rob_inflight),
      .epc(epc),
      .dbg_frozen(dbg_frozen),
      .dbg_wp_data(dbg_wp_data),
      .l1i_flush_done(l1i_flush_done),
      .l1d_flush_done(l1d_flush_done),
      .l2_flush_done(l2_flush_done),
      .ext_flush_req(ext_flush_req | w_sr_flush),
      .ext_flush_done(w_core_flush_done),
      .ext_flush_ppn(ext_flush_ppn),
      .ext_flush_whole(ext_flush_whole | w_sr_flush),
      .ext_flush_drop(ext_flush_drop & !w_sr_flush),
      .ext_flush_dirty_cnt(ext_flush_dirty_cnt),
      .dbg_flush(dbg_flush),
      .dma_inval_req(dma_inval_req),
      .dma_inval_addr(dma_inval_addr),
      .dma_inval_ack(dma_inval_ack),
      .snoop_req_valid(snoop_req_valid),
      .snoop_req_addr(snoop_req_addr),
      .snoop_req_ack(snoop_req_ack),
      .snoop_req_wbinv(snoop_req_wbinv),
      .snoop_done(snoop_done),
      .dbg_head_pc(dbg_head_pc),
      .dbg_head_status(dbg_head_status),
      .dbg_head_fetch_cycle(dbg_head_fetch_cycle),
      .dbg_head_alloc_cycle(dbg_head_alloc_cycle),
      .dbg_serialize_cycle(dbg_serialize_cycle),
      .dbg_cycle(dbg_cycle),
      .dbg_oldest_first_pending(dbg_oldest_first_pending),
      .dbg_trace_index(dbg_trace_index),
      .dbg_trace_data(dbg_trace_data),
      .dbg_trace_wptr(dbg_trace_wptr)
      );

   // =====================================================================
   //  Device decode (physical; c_req_addr is a 16-byte line).  A request for
   //  an RTL device is answered here; everything else passes through on the
   //  external memory bus (RAM, the boot PROM and the devices still modeled
   //  outside the SoC).
   // =====================================================================
   wire w_is_slavio = (c_req_addr[`PA_WIDTH-1:24] == 12'hff1);
   wire w_line0 = (c_req_addr[11:4] == 8'd0);
   wire w_is_misc = w_is_slavio & w_line0 &
		    ((c_req_addr[23:12] == 12'h600) |
		     (c_req_addr[23:12] == 12'h800) |
		     (c_req_addr[23:12] == 12'ha00) |
		     (c_req_addr[23:12] == 12'ha01) |
		     (c_req_addr[23:12] == 12'hb00) |
		     (c_req_addr[23:12] == 12'hf00));
   /* counter/timers: system 0xff1310000 (0x14 bytes), CPU n 0xff130n000 (0x10, n < 4) */
   wire w_is_timer = w_is_slavio &
		     (((c_req_addr[23:4] == 20'h31000)) |
		      ((c_req_addr[23:4] == 20'h31001) & (c_req_mask[15:4] == 12'd0)) |
		      ((c_req_addr[23:14] == 10'h0c0) & w_line0));
   /* interrupt controller: master 0xff1410000 (0x14 bytes), CPU n's slave 0xff140n000 (0x10) */
   wire w_is_intctl = w_is_slavio &
		      (((c_req_addr[23:4] == 20'h41000)) |
		       ((c_req_addr[23:4] == 20'h41001) & (c_req_mask[15:4] == 12'd0)) |
		       ((c_req_addr[23:16] == 8'h40) & w_line0));
   /* memory controller registers: 0xf00000000, nine words */
   wire w_is_ecc = (c_req_addr[`PA_WIDTH-1:6] == 30'h3c000000) &
		   ((c_req_addr[5:4] != 2'd3) & ((c_req_addr[5:4] != 2'd2) | (c_req_mask[15:4] == 12'd0)));
   /* IOMMU registers: 0xfe0000000, 16 KB */
   wire w_is_iommu = (c_req_addr[`PA_WIDTH-1:14] == 22'h3f8000);
   wire w_is_dev = w_is_misc | w_is_timer | w_is_intctl | w_is_ecc | w_is_iommu;
   /* RAM (the installed size: OBP sizes memory by probing, and an access past it is a
    * bus error the ARM answers) and the boot PROM go to the memory bus; every other
    * device goes to the ARM-served window */
   wire w_is_ram = (c_req_addr < `PA_WIDTH'(RAM_BYTES));
   wire w_is_prom = (c_req_addr[`PA_WIDTH-1:20] == 16'hff00);
   /* the CG14's VRAM (VSIMM slot 3: 0xfc000000, 64 MB, an 8 MB VRAM aliasing through
    * it) is plain memory: it goes to the memory bus like the PROM (the AXI wrapper
    * folds it onto 8 MB of DRAM, where the ARM copies the screen out in bulk), not
    * a 32-bit-at-a-time trip through the window.  The CG14's registers stay on the
    * window. */
   wire w_is_vram = (c_req_addr[`PA_WIDTH-1:26] == 10'h03f);
   wire w_is_win = !w_is_ram & !w_is_prom & !w_is_vram & !w_is_dev;

   // =====================================================================
   //  Device request FSM (Henry's): one request outstanding, as on the core
   //  bus.  On accept the selected device's combinational rdata is latched
   //  and a store takes effect; the response follows DEV_LAT cycles later.
   //  An atomic (ldstub 8 / swap 9) is both: the old value is latched and the
   //  store data written in the same accept cycle.
   // =====================================================================
   localparam DEV_LAT = 2;
   logic r_dev_busy;
   logic n_dev_busy;
   logic [1:0] r_dev_cnt;
   logic [1:0] n_dev_cnt;
   logic [127:0] r_dev_rdata;
   logic [127:0] n_dev_rdata;
   wire [127:0] w_rd_misc;
   wire [127:0] w_rd_timer;
   wire [127:0] w_rd_intctl;
   wire w_sys_timer_irq;
   wire w_cpu0_timer_irq;

   wire w_dev_accept = c_req_valid & w_is_dev & !r_dev_busy & !w_sr_core_reset;
   wire w_dev_store = (c_req_opcode == 5'd7) | (c_req_opcode == 5'd8) | (c_req_opcode == 5'd9);
   wire w_dev_rsp = r_dev_busy & (r_dev_cnt == 2'd0);
   wire [127:0] w_rd_ecc;
   wire [127:0] w_rd_iommu;
   wire [127:0] w_dev_rdata = w_rd_misc | w_rd_timer | w_rd_intctl | w_rd_ecc | w_rd_iommu;

   ecc_memctl u_ecc
     (
      .clk(clk),
      .reset(reset | w_sr_dev_reset),
      .sel(w_dev_accept & w_is_ecc),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_ecc)
      );

   sbus_iommu u_iommu
     (
      .clk(clk),
      .reset(reset | w_sr_dev_reset),
      .sel(w_dev_accept & w_is_iommu),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_iommu),
      .ctrl(iommu_ctrl),
      .base(iommu_base)
      );

   slavio_misc u_misc
     (.clk(clk),
      .reset(reset),
      .sys_reset(w_sr_dev_reset),
      .sel(w_dev_accept & w_is_misc),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_misc),
      .sys_reset_req(w_sys_reset_req)
      );

   slavio_timer u_timer
     (.clk(clk),
      .reset(reset | w_sr_dev_reset),
      .sel(w_dev_accept & w_is_timer),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_timer),
      .sys_irq(w_sys_timer_irq),
      .cpu0_irq(w_cpu0_timer_irq)
      );

   /* source 19 = the system timer (level 10) */
   slavio_intctl u_intctl
     (.clk(clk),
      .reset(reset | w_sr_dev_reset),
      .sel(w_dev_accept & w_is_intctl),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_intctl),
      .src(ext_irq | {12'd0, w_sys_timer_irq, 19'd0}),
      .cpu0_timer(w_cpu0_timer_irq),
      .irl(w_irl)
      );

   always_comb
     begin
	n_dev_busy = r_dev_busy;
	n_dev_cnt = r_dev_cnt;
	n_dev_rdata = r_dev_rdata;
	if(w_dev_accept)
	  begin
	     n_dev_busy = 1'b1;
	     n_dev_cnt = 2'(DEV_LAT);
	     n_dev_rdata = w_dev_rdata;
	  end
	else if(r_dev_busy)
	  begin
	     if(r_dev_cnt == 2'd0)
	       begin
		  n_dev_busy = 1'b0;
	       end
	     else
	       begin
		  n_dev_cnt = r_dev_cnt - 2'd1;
	       end
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_dev_busy <= 1'b0;
	     r_dev_cnt <= 2'd0;
	     r_dev_rdata <= 128'd0;
	  end
	else
	  begin
	     r_dev_busy <= n_dev_busy;
	     r_dev_cnt <= n_dev_cnt;
	     r_dev_rdata <= n_dev_rdata;
	  end
     end // always_ff

   // =====================================================================
   //  The ARM-served window: one access at a time, like the device FSM.  The
   //  window's done ends it (a posted store at once, a load or atomic when the
   //  ARM answers); busy clears the cycle after, when the core drops the request.
   // =====================================================================
   logic r_win_busy;
   logic n_win_busy;
   wire w_win_sel = c_req_valid & w_is_win & !r_win_busy & !w_sr_core_reset;
   wire w_win_done;
   wire w_win_bad;
   wire w_win_retry;
   wire [127:0] w_win_rdata;

   arm_window u_win
     (
      .clk(clk),
      .reset(reset),
      .sel(w_win_sel),
      .opcode(c_req_opcode),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .done(w_win_done),
      .bad(w_win_bad),
      .retry(w_win_retry),
      .rdata(w_win_rdata),
      .cons(win_cons),
      .ans_lo(win_ans_lo),
      .ans_hi(win_ans_hi),
      .ans_seq(win_ans_seq),
      .prod(win_prod),
      .pend(win_pend),
      .pend_seq(win_pend_seq),
      .mem_req_valid(mem2_req_valid),
      .mem_req_addr(mem2_req_addr),
      .mem_req_opcode(mem2_req_opcode),
      .mem_req_store_data(mem2_req_store_data),
      .mem_req_mask(mem2_req_mask),
      .mem_rsp_valid(mem2_rsp_valid)
      );

   always_comb
     begin
	n_win_busy = r_win_busy;
	if(w_win_sel)
	  begin
	     n_win_busy = 1'b1;
	  end
	else if(w_win_done)
	  begin
	     n_win_busy = 1'b0;
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_win_busy <= 1'b0;
	  end
	else
	  begin
	     r_win_busy <= n_win_busy;
	  end
     end // always_ff

   // =====================================================================
   //  An uncached ldstub/swap to RAM (opcode 8/9: the caches off, or MMU-off
   //  AC=0) is a read-modify-write on the memory bus, which only reads and
   //  writes: read the line (under the atomic's mask), one idle cycle (the bus
   //  wants the request to drop between two), write the store data under the
   //  mask, then answer with what was read.  A bus error on the read answers at
   //  once and skips the write.  The core holds the request until the answer.
   // =====================================================================
   typedef enum logic [1:0] {
      AT_IDLE,
      AT_RD,
      AT_GAP,
      AT_WR
   } at_state_t;
   at_state_t r_at_state;
   at_state_t n_at_state;
   logic [127:0] r_at_rdata;
   logic [127:0] n_at_rdata;
   logic t_at_done;
   logic t_at_bad;
   wire w_mem_sel = c_req_valid & (w_is_ram | w_is_prom | w_is_vram) & !w_sr_core_reset;
   wire w_mem_atomic = (c_req_opcode == 5'd8) | (c_req_opcode == 5'd9);

   always_comb
     begin
	n_at_state = r_at_state;
	n_at_rdata = r_at_rdata;
	t_at_done = 1'b0;
	t_at_bad = 1'b0;
	case(r_at_state)
	  AT_IDLE:
	    begin
	       if(w_mem_sel & w_mem_atomic)
		 begin
		    n_at_state = AT_RD;
		 end
	    end
	  AT_RD:
	    begin
	       if(mem_rsp_valid)
		 begin
		    n_at_rdata = mem_rsp_load_data;
		    if(mem_rsp_bad)
		      begin
			 t_at_done = 1'b1;
			 t_at_bad = 1'b1;
			 n_at_state = AT_IDLE;
		      end
		    else
		      begin
			 n_at_state = AT_GAP;
		      end
		 end
	    end
	  AT_GAP:
	    begin
	       n_at_state = AT_WR;
	    end
	  AT_WR:
	    begin
	       if(mem_rsp_valid)
		 begin
		    t_at_done = 1'b1;
		    t_at_bad = mem_rsp_bad;
		    n_at_state = AT_IDLE;
		 end
	    end
	  default:
	    begin
	       n_at_state = AT_IDLE;
	    end
	endcase // case (r_at_state)
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_at_state <= AT_IDLE;
	     r_at_rdata <= 128'd0;
	  end
	else
	  begin
	     r_at_state <= n_at_state;
	     r_at_rdata <= n_at_rdata;
	  end
     end // always_ff

   assign mem_req_valid = w_mem_sel & (!w_mem_atomic | (r_at_state == AT_RD) | (r_at_state == AT_WR));
   assign mem_req_addr = c_req_addr;
   assign mem_req_store_data = c_req_store_data;
   assign mem_req_opcode = !w_mem_atomic ? c_req_opcode : ((r_at_state == AT_RD) ? 5'd4 : 5'd7);
   assign mem_req_mask = c_req_mask;
   assign mem_req_uncached = c_req_uncached;

   wire w_mem_rsp = mem_rsp_valid & !w_mem_atomic;
   assign c_rsp_valid = w_dev_rsp | w_win_done | w_mem_rsp | t_at_done;
   assign c_rsp_retry = w_win_done & w_win_retry;
   assign c_rsp_bad = w_dev_rsp ? 1'b0 : (w_win_done ? w_win_bad : (t_at_done ? t_at_bad : mem_rsp_bad));
   assign c_rsp_load_data = w_dev_rsp ? r_dev_rdata :
			    (w_win_done ? w_win_rdata :
			     (t_at_done ? ((r_at_state == AT_RD) ? mem_rsp_load_data : r_at_rdata) : mem_rsp_load_data));

   // =====================================================================
   //  System reset (a sysctrl write of bit 0, slavio_misc).  ss10sim's
   //  system_reset: the CPU and the devices back to their reset state, RAM,
   //  the PROM, NVRAM and the surviving SLAVIO registers kept, and the CPU
   //  restarts at pc 0.  The sequence:
   //    FLUSH: the core writes back and invalidates its caches (its external
   //      flush, a serializing op), so RAM has every store it retired;
   //    DRAIN: no more retirement; wait until the core's memory bus is idle
   //      (one request at a time: no request means none outstanding);
   //    RESET: the core in reset (sys_reset: the MMU keeps its context, table
   //      pointer and fault registers) for RESET_CYCLES -- the co-sim seeds the
   //      core's register files one entry per cycle while it is held -- and the
   //      devices for its first cycle;
   //    RESUME: once the core is ready and the ARM has reset its device models
   //      (sys_reset_ack == sys_reset_cnt: ZS, NVRAM, ESP, Lance and the rest of
   //      the window's devices live on the ARM), resume it at pc 0.  Without
   //      the wait the PROM ran on devices still in the OS's state (a pending
   //      ESP interrupt, DMA set up) until the ARM noticed the reset.
   //  A request while the sequence runs is ignored (OBP repeats the write
   //  until the reset happens).
   // =====================================================================
   localparam RESET_CYCLES = 4096;
   always_comb
     begin
	n_sr_state = r_sr_state;
	n_sr_cnt = r_sr_cnt;
	case(r_sr_state)
	  SR_IDLE:
	    begin
	       if(w_sys_reset_req)
		 begin
		    n_sr_state = SR_FLUSH_REQ;
		 end
	    end
	  SR_FLUSH_REQ:
	    begin
	       n_sr_state = SR_FLUSH_WAIT;
	    end
	  SR_FLUSH_WAIT:
	    begin
	       if(w_core_flush_done)
		 begin
		    n_sr_state = SR_DRAIN;
		 end
	    end
	  SR_DRAIN:
	    begin
	       if(!c_req_valid & !r_dev_busy & !r_win_busy)
		 begin
		    n_sr_state = SR_RESET;
		    n_sr_cnt = 13'd0;
		 end
	    end
	  SR_RESET:
	    begin
	       n_sr_cnt = r_sr_cnt + 13'd1;
	       if(r_sr_cnt == 13'(RESET_CYCLES - 1))
		 begin
		    n_sr_state = SR_RESUME_WAIT;
		 end
	    end
	  SR_RESUME_WAIT:
	    begin
	       if(ready_for_resume & (sys_reset_ack == sys_reset_cnt))
		 begin
		    n_sr_state = SR_RESUME;
		 end
	    end
	  SR_RESUME:
	    begin
	       n_sr_state = SR_IDLE;
	    end
	  default:
	    begin
	       n_sr_state = SR_IDLE;
	    end
	endcase
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_sr_state <= SR_IDLE;
	     r_sr_cnt <= 13'd0;
	  end
	else
	  begin
	     r_sr_state <= n_sr_state;
	     r_sr_cnt <= n_sr_cnt;
	  end
     end // always_ff

   assign ext_flush_done = w_core_flush_done & (r_sr_state != SR_FLUSH_WAIT);

   logic [31:0] r_sys_reset_cnt;
   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_sys_reset_cnt <= 32'd0;
	  end
	else if(w_sr_dev_reset)
	  begin
	     r_sys_reset_cnt <= r_sys_reset_cnt + 32'd1;
	  end
     end // always_ff
   assign sys_reset_cnt = r_sys_reset_cnt;

`ifdef VERILATOR
   always_ff @(posedge clk)
     begin
	if(!reset && (n_sr_state != r_sr_state))
	  begin
	     $display("[SYSRST] cycle %0d: state %0d -> %0d", r_sim_cycle, r_sr_state, n_sr_state);
	  end
     end // always_ff
   assign sim_sys_reset = w_sr_dev_reset;
   logic [63:0] r_sim_cycle;
   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_sim_cycle <= 64'd0;
	  end
	else
	  begin
	     r_sim_cycle <= r_sim_cycle + 64'd1;
	  end
     end // always_ff
   assign sim_cycle = r_sim_cycle;
   assign sim_irl = w_irl;
   assign dev_tap_valid = w_dev_accept;
   assign dev_tap_addr = c_req_addr;
   assign dev_tap_mask = c_req_mask;
   assign dev_tap_opcode = c_req_opcode;
   assign dev_tap_store_data = c_req_store_data;
   assign dev_tap_load_data = w_dev_rdata;
`endif

endmodule // kodiak_soc
