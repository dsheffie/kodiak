// -----------------------------------------------------------------------------
// kodiak_soc.sv -- Kodiak, the wannabe SPARCstation 20 (sun4m) SoC: top level.
//
// Wraps the superdupersparc core (core_l1d_l1i, the superdupersparc submodule).
// Bring-up step A: the SoC has no RTL devices yet, so every core request (RAM,
// the boot PROM and all device space) passes through on the external memory bus
// unchanged; the testbench answers device space with ss10sim's C++ sun4m models.
// The SS-20 devices move in here one at a time, re-targeted from Henry's (the
// IP22 SoC this repo was forked from), behind a physical-address decode on the
// core's 16-byte line bus, as henry_soc did.
//
// The ports are the core's, under the same names, so the co-sim testbench (a
// copy of superdupersparc's top.cc) drives the SoC as it drove the bare core.
// -----------------------------------------------------------------------------
`include "machine.vh"

module kodiak_soc(
clk,
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
		  irl,
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
   input logic [3:0] irl;
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
      .mem_req_valid(mem_req_valid),
      .mem_req_addr(mem_req_addr),
      .mem_req_store_data(mem_req_store_data),
      .mem_req_opcode(mem_req_opcode),
      .mem_req_mask(mem_req_mask),
      .mem_req_uncached(mem_req_uncached),
      .mem_rsp_valid(mem_rsp_valid),
      .mem_rsp_bad(mem_rsp_bad),
      .mem_rsp_load_data(mem_rsp_load_data),
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
      .irl(irl),
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

endmodule // kodiak_soc
