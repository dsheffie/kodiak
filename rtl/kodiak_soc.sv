// -----------------------------------------------------------------------------
// kodiak_soc.sv -- Kodiak, the wannabe SPARCstation 20 (sun4m) SoC: top level.
//
// Wraps the superdupersparc core (core_l1d_l1i, the superdupersparc submodule).
// The core's 16-byte line bus goes through a physical-address decode, as in
// henry_soc: a request for an RTL device is answered here; everything else
// (RAM, the boot PROM and the devices not yet in RTL) passes through on the
// external memory bus, where the testbench answers device space with
// ss10sim's C++ sun4m models.  The SS-20 devices move in one at a time,
// re-targeted from Henry's (the IP22 SoC this repo was forked from).
//
// The ports are the core's, under the same names, so the co-sim testbench (a
// copy of superdupersparc's top.cc) drives the SoC as it drove the bare core,
// plus a sim-only tap of the accesses the RTL devices answer.
// -----------------------------------------------------------------------------
`include "machine.vh"

module kodiak_soc(clk,
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

   /* the core's memory bus, ahead of the device decode */
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
      .retire_allowed(retire_allowed),
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
      .resume(resume),
      .resume_pc(resume_pc),
      .ready_for_resume(ready_for_resume),
      .mem_req_valid(c_req_valid),
      .mem_req_addr(c_req_addr),
      .mem_req_store_data(c_req_store_data),
      .mem_req_opcode(c_req_opcode),
      .mem_req_mask(c_req_mask),
      .mem_req_uncached(c_req_uncached),
      .mem_rsp_valid(c_rsp_valid),
      .mem_rsp_bad(c_rsp_bad),
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
      .ext_flush_req(ext_flush_req),
      .ext_flush_done(ext_flush_done),
      .ext_flush_ppn(ext_flush_ppn),
      .ext_flush_whole(ext_flush_whole),
      .ext_flush_drop(ext_flush_drop),
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
   wire w_is_dev = w_is_misc | w_is_timer | w_is_intctl;

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

   wire w_dev_accept = c_req_valid & w_is_dev & !r_dev_busy;
   wire w_dev_store = (c_req_opcode == 5'd7) | (c_req_opcode == 5'd8) | (c_req_opcode == 5'd9);
   wire w_dev_rsp = r_dev_busy & (r_dev_cnt == 2'd0);
   wire [127:0] w_dev_rdata = w_rd_misc | w_rd_timer | w_rd_intctl;

   slavio_misc u_misc
     (.clk(clk),
      .reset(reset),
      .sel(w_dev_accept & w_is_misc),
      .is_store(w_dev_store),
      .addr(c_req_addr),
      .mask(c_req_mask),
      .wdata(c_req_store_data),
      .rdata(w_rd_misc)
      );

   slavio_timer u_timer
     (.clk(clk),
      .reset(reset),
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
      .reset(reset),
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

   assign mem_req_valid = c_req_valid & !w_is_dev;
   assign mem_req_addr = c_req_addr;
   assign mem_req_store_data = c_req_store_data;
   assign mem_req_opcode = c_req_opcode;
   assign mem_req_mask = c_req_mask;
   assign mem_req_uncached = c_req_uncached;

   assign c_rsp_valid = w_dev_rsp | mem_rsp_valid;
   assign c_rsp_bad = w_dev_rsp ? 1'b0 : mem_rsp_bad;
   assign c_rsp_load_data = w_dev_rsp ? r_dev_rdata : mem_rsp_load_data;

`ifdef VERILATOR
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
