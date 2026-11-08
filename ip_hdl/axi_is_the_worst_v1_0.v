
`timescale 1 ns / 1 ps


module axi_is_the_worst_v1_0 #
  (
   // Users to add parameters here

   // User parameters ends
   // Do not modify the parameters beyond this line


   // Parameters of Axi Slave Bus Interface S00_AXI
   parameter integer C_S00_AXI_DATA_WIDTH = 32,
   parameter integer C_S00_AXI_ADDR_WIDTH = 8, 
		     
   // Parameters of Axi Master Bus Interface M00_AXI
   parameter C_M00_AXI_TARGET_SLAVE_BASE_ADDR = 32'h40000000,
   parameter integer C_M00_AXI_BURST_LEN = 1,
   parameter integer C_M00_AXI_ID_WIDTH = 1,
   parameter integer C_M00_AXI_ADDR_WIDTH = 32,
   parameter integer C_M00_AXI_DATA_WIDTH = 128,
   parameter integer C_M00_AXI_AWUSER_WIDTH = 0,
   parameter integer C_M00_AXI_ARUSER_WIDTH = 0,
   parameter integer C_M00_AXI_WUSER_WIDTH = 0,
   parameter integer C_M00_AXI_RUSER_WIDTH = 0,
   parameter integer C_M00_AXI_BUSER_WIDTH = 0
   )
   (
    // Users to add ports here

    // User ports ends
    // Do not modify the ports beyond this line


    // Ports of Axi Slave Bus Interface S00_AXI
    input wire 					s00_axi_aclk,
    input wire 					s00_axi_aresetn,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] 	s00_axi_awaddr,
    input wire [2 : 0] 				s00_axi_awprot,
    input wire 					s00_axi_awvalid,
    output wire 				s00_axi_awready,
    input wire [C_S00_AXI_DATA_WIDTH-1 : 0] 	s00_axi_wdata,
    input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
    input wire 					s00_axi_wvalid,
    output wire 				s00_axi_wready,
    output wire [1 : 0] 			s00_axi_bresp,
    output wire 				s00_axi_bvalid,
    input wire 					s00_axi_bready,
    input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] 	s00_axi_araddr,
    input wire [2 : 0] 				s00_axi_arprot,
    input wire 					s00_axi_arvalid,
    output wire 				s00_axi_arready,
    output wire [C_S00_AXI_DATA_WIDTH-1 : 0] 	s00_axi_rdata,
    output wire [1 : 0] 			s00_axi_rresp,
    output wire 				s00_axi_rvalid,
    input wire 					s00_axi_rready,

    // Ports of Axi Master Bus Interface M00_AXI
    input wire 					m00_axi_init_axi_txn,
    output wire 				m00_axi_txn_done,
    output wire 				m00_axi_error,
    input wire 					m00_axi_aclk,
    input wire 					m00_axi_aresetn,
    output wire [C_M00_AXI_ID_WIDTH-1 : 0] 	m00_axi_awid,
    output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] 	m00_axi_awaddr,
    output wire [7 : 0] 			m00_axi_awlen,
    output wire [2 : 0] 			m00_axi_awsize,
    output wire [1 : 0] 			m00_axi_awburst,
    output wire 				m00_axi_awlock,
    output wire [3 : 0] 			m00_axi_awcache,
    output wire [2 : 0] 			m00_axi_awprot,
    output wire [3 : 0] 			m00_axi_awqos,
    output wire [C_M00_AXI_AWUSER_WIDTH-1 : 0] 	m00_axi_awuser,
    output wire 				m00_axi_awvalid,
    input wire 					m00_axi_awready,
    output wire [C_M00_AXI_DATA_WIDTH-1 : 0] 	m00_axi_wdata,
    output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] 	m00_axi_wstrb,
    output wire 				m00_axi_wlast,
    output wire [C_M00_AXI_WUSER_WIDTH-1 : 0] 	m00_axi_wuser,
    output wire 				m00_axi_wvalid,
    input wire 					m00_axi_wready,
    input wire [C_M00_AXI_ID_WIDTH-1 : 0] 	m00_axi_bid,
    input wire [1 : 0] 				m00_axi_bresp,
    input wire [C_M00_AXI_BUSER_WIDTH-1 : 0] 	m00_axi_buser,
    input wire 					m00_axi_bvalid,
    output wire 				m00_axi_bready,
    output wire [C_M00_AXI_ID_WIDTH-1 : 0] 	m00_axi_arid,
    output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] 	m00_axi_araddr,
    output wire [7 : 0] 			m00_axi_arlen,
    output wire [2 : 0] 			m00_axi_arsize,
    output wire [1 : 0] 			m00_axi_arburst,
    output wire 				m00_axi_arlock,
    output wire [3 : 0] 			m00_axi_arcache,
    output wire [2 : 0] 			m00_axi_arprot,
    output wire [3 : 0] 			m00_axi_arqos,
    output wire [C_M00_AXI_ARUSER_WIDTH-1 : 0] 	m00_axi_aruser,
    output wire 				m00_axi_arvalid,
    input wire 					m00_axi_arready,
    input wire [C_M00_AXI_ID_WIDTH-1 : 0] 	m00_axi_rid,
    input wire [C_M00_AXI_DATA_WIDTH-1 : 0] 	m00_axi_rdata,
    input wire [1 : 0] 				m00_axi_rresp,
    input wire 					m00_axi_rlast,
    input wire [C_M00_AXI_RUSER_WIDTH-1 : 0] 	m00_axi_ruser,
    input wire 					m00_axi_rvalid,
    output wire 				m00_axi_rready
    );
   wire [31:0] 					w_controlreg,w_baseaddr,w_status;
   wire [31:0]					w_addrmask;
   
   /* Full 36-bit physical address.  henry_soc drives PA_WIDTH=36; truncating it
    * here dropped PA[35:32] AND defeated the out-of-range poison, because
    * M00_AXI's `w_bad_addr = (t_cpuaddr > addrmask)` then compared the ALREADY
    * TRUNCATED value -- so a high-PFN access was laundered into an in-range
    * address and read real DRAM at the wrong line instead of returning
    * 0xA5A5A5A5.  The AXI bus itself is 32-bit and cannot widen, so the rule is:
    * range-check at full width, truncate only at the bus. */
   wire [35:0] 					w_mem_req_addr;
   wire [31:0] 					w_axi_addr = w_baseaddr+(w_mem_req_addr[31:0]);

   wire [127:0]					w_mem_req_store_data;
   wire						w_axi_busy;
   
   
   //outputs to axi slave
   wire [31:0] 					w_rvcontrol, w_resume_pc;
   wire [31:0] 					w_bp_pc;   // driver-programmable breakpoint PC (slv_reg9)
   wire [31:0] 					w_bp_wp_addr; // store-address watchpoint VA (slv_reg10)
   wire [31:0] 					w_bp_wp_val;  // expected corrupt store value (slv_reg11)

   //inputs to axi slave
   /* These carry `M_WIDTH (64b) values from henry_soc but the AXI readback
    * registers are 32b, so only the low half is visible.  The truncation is
    * made EXPLICIT below ([31:0] on the port connection) instead of being left
    * to an implicit width mismatch: the limit is real (true 64b visibility
    * needs new readback registers -- 0x1B-0x25 are free) but it should not be
    * silent.  For the o32 userspace code in the 2026-09-02 captures this is
    * lossless; a genuinely 64-bit-wrong value would NOT be visible. */
   wire [63:0] 					w_epc64, w_badvaddr64;
   wire [31:0] 					w_rvstatus;
   wire [31:0] 					w_epc      = w_epc64[31:0];
   wire [31:0] 					w_badvaddr = w_badvaddr64[31:0];
   wire [31:0] 					w_wf_epc, w_wf_badv, w_wf_stat;   // wild-fault latch
   wire [31:0]					w_states;
   wire [4:0]					w_cause;
   wire [2:0]					w_dbg_frozen;
   wire [31:0]					w_dbg_wp_data;
   /* MUST be 20 bits: dbg_trace_index is declared [19:0] at BOTH ends, but this
    * intermediate wire was [11:0], silently dropping bits [19:12] -- which is the
    * entire ring WORD select ({index[18], index[16:15]}).  Row/bank ([10:1]) fit
    * in 12 bits and worked, so every dump returned word 0 (the pc) for all 7
    * words and the ring was undecodable.  Verilog gives no width warning here.
    * Stale comment on the S00_AXI side still says {row[7:0],word[3:0]}, which is
    * what 12 bits was sized for before the ring grew to 2048 entries. */
   wire [19:0]					w_trace_index;
   wire [31:0]					w_trace_data;
   wire [63:0]					w_dbg_head_pc;
   wire [31:0]					w_dbg_head_status;
   /* WAS [8:0], which truncated a 16-bit bus: core.sv drives
    * {r_rtrace_frozen, 4'd0, r_rtrace_ptr[9:0], 1'b0}, so bit15 is the ring's
    * FROZEN flag and [10:1] the pair index.  At 9 bits the readback carried only
    * ptr[7:0] and the frozen flag was UNREADABLE -- a freeze could only be
    * inferred from wptr going static, which is ambiguous against a parked core.
    * Widened to the full 16 the S00_AXI port already expects (reg 0x19). */
   wire [15:0]					w_trace_wptr;
   wire [31:0]					w_trace_ring_wptr;   // DRAM deep-trace: bytes written since arm
   wire [31:0]					w_dbg_rob_inflight;   /* {l1d r_rob_inflight[15:0], core r_rob_inflight[15:0]} */
   (* shreg_extract = "no", srl_style = "register" *) reg [31:0] r_dbg_rob_p1, r_dbg_rob_p2, r_dbg_rob_p3;
   always @(posedge s00_axi_aclk) begin r_dbg_rob_p1 <= w_dbg_rob_inflight; r_dbg_rob_p2 <= r_dbg_rob_p1; r_dbg_rob_p3 <= r_dbg_rob_p2; end
   wire						w_trace_overflow;    // DRAM deep-trace: a record was dropped
   wire [7:0]					w_cur_asid;          // current EntryHi ASID readback (be-ASID discovery)
   wire						w_l1i_flush_done, w_l1d_flush_done, w_l2_flush_done;
   
   

   wire [31:0] 					w_pc, w_pc2;
   wire [6:0]					w_op, w_op2;
   
   wire 					w_pc_valid, w_pc2_valid;
   
   wire 					w_reset_out, 
						w_in_flush,
						w_ready, 
						w_got_break,
						w_got_ud,
						w_got_bad_addr;

   wire [4:0]					w_state; //5
   wire [3:0]					w_dstate, w_l2state,  w_axistate, w_l2rsp_state; //12
   wire [2:0]					w_istate; //3
   

   /* ---- cache performance counters: PIPELINED, deliberately ------------------
    * These six buses run from counter flops deep inside l1i/l1d/l2 all the way
    * to the 64-entry AXI readback mux, and they have historically been a major
    * source of timing pressure on this design: a long cross-chip route feeding
    * wide combinational select logic.
    *
    * They are DEBUG counters that software samples at Hz rates, so latency is
    * entirely free -- 10 cycles of skew is invisible.  Flopping the path lets the
    * placer/router break one long hop into ten short ones.
    *
    * Only [31:0] is ever read back (regs 0x2C-0x2F, 0x36, 0x37; the upper halves
    * were repurposed to make room for these very registers), so the pipeline is
    * 32 bits wide, not 64 -- half the flops for the same benefit.
    *
    * THE TRAP: a plain flop chain gets absorbed into an SRL16/SRL32, which puts
    * all ten stages in ONE LUT at ONE site and defeats the entire purpose while
    * looking correct in simulation.  cnt_pipe carries shreg_extract="no" and
    * srl_style="register" to force real distributed flops.  Check it held:
    *   check "LUT as Memory" in the impl utilization report does not grow. */
   wire [63:0] 					w_l1i_cache_accesses;
   wire [63:0] 					w_l1i_cache_hits;
   wire [63:0] 					w_l1d_cache_accesses;
   wire [63:0] 					w_l1d_cache_hits;
   wire [63:0] 					w_l2_cache_accesses;
   wire [63:0] 					w_l2_cache_hits;
   wire [31:0] 					w_l1i_acc_q;
   wire [31:0] 					w_l1i_hit_q;
   wire [31:0] 					w_l1d_acc_q;
   wire [31:0] 					w_l1d_hit_q;
   wire [31:0] 					w_l2_acc_q;
   wire [31:0] 					w_l2_hit_q;

   /* ---- CACHE COUNTERS DISABLED 2026-09-12 ---------------------------------
    * Tied off to land a bitstream.  Two full impl runs of this design WITH the
    * counters (both strategies, ~5h wall clock) failed to close: post-route
    * phys_opt reached WNS +0.14 / +0.06 with TNS 0, and the following routing
    * pass tore it back open every time.  These six buses run from counter flops
    * deep inside l1i/l1d/l2 to the 64-entry AXI readback mux and have always put
    * heavy timing pressure on the design.
    *
    * Pipelining them (cnt_pipe, 10 stages) was VERIFIED to work as intended --
    * placed FFs 42160 -> 44082 (+1922 vs +1920 predicted), LUT-as-Memory and
    * shift-registers both UNCHANGED at 2545/171, so the flops stayed real and
    * were not absorbed into SRLs.  It still was not enough to close timing, so
    * the counters come out entirely for now.
    *
    * TO RESTORE: uncomment the cnt_pipe instances below and swap the six
    * .l1*_cache_* connections on the S00_AXI instance back to {32'd0, w_*_q}.
    * The cnt_pipe module itself is kept (bottom of this file) -- unused modules
    * cost nothing and the attributes on it are the non-obvious part. */
//   cnt_pipe #(.W(32), .N(10)) pipe_l1i_acc (
//	.clk(s00_axi_aclk),
//	.in(w_l1i_cache_accesses[31:0]),
//	.out(w_l1i_acc_q)
//	);
//   cnt_pipe #(.W(32), .N(10)) pipe_l1i_hit (
//	.clk(s00_axi_aclk),
//	.in(w_l1i_cache_hits[31:0]),
//	.out(w_l1i_hit_q)
//	);
//   cnt_pipe #(.W(32), .N(10)) pipe_l1d_acc (
//	.clk(s00_axi_aclk),
//	.in(w_l1d_cache_accesses[31:0]),
//	.out(w_l1d_acc_q)
//	);
//   cnt_pipe #(.W(32), .N(10)) pipe_l1d_hit (
//	.clk(s00_axi_aclk),
//	.in(w_l1d_cache_hits[31:0]),
//	.out(w_l1d_hit_q)
//	);
//   cnt_pipe #(.W(32), .N(10)) pipe_l2_acc (
//	.clk(s00_axi_aclk),
//	.in(w_l2_cache_accesses[31:0]),
//	.out(w_l2_acc_q)
//	);
//   cnt_pipe #(.W(32), .N(10)) pipe_l2_hit (
//	.clk(s00_axi_aclk),
//	.in(w_l2_cache_hits[31:0]),
//	.out(w_l2_hit_q)
//	);
   wire [63:0]					w_l2_early_accesses = 'd0;
   

   wire [63:0]					w_axi_writes;
   wire [63:0]					w_axi_reads;   
   
   
   wire [63:0]					w_txn_lat, w_txn_cnt;
   wire 					w_reset = (s00_axi_aresetn==1'b0);
   
   
   //connects to axi master
   wire 					w_mem_req_valid, w_mem_rsp_valid;
   wire						w_mem_rsp_bad;
   
   wire [15:0]					w_mem_req_mask;
   
   wire						w_mem_req_gnt;
   wire [1:0]					w_mem_req_tag, w_mem_rsp_tag;

   assign w_mem_req_tag = 2'd0;
   
   
   wire [4:0]					w_mem_req_opcode;
   wire [127:0]					w_load_data;
   /* lane 1 of the M00 master (AXI ID 1): henry_soc's DMA / gio ring / MC fill port */
   wire					w_mem2_req_valid, w_mem2_rsp_valid, w_mem2_rsp_bad;
   wire [35:0]					w_mem2_req_addr;
   wire [4:0]					w_mem2_req_opcode;
   wire [15:0]					w_mem2_req_mask;
   wire [511:0]					w_mem2_req_store_data, w_mem2_load_data;
   
   wire						w_memq_empty;
   wire [5:0]					w_inflight;   /* soc drives LG_ROB_ENTRIES+1 = 5b; upper bit reads 0 */

   wire [4:0]					w_reg_ptr0, w_reg_ptr1;
   wire [31:0]					w_reg_data0, w_reg_data1;
   wire						w_reg_val0, w_reg_val1;
   
   
   wire 					w_putchar_fifo_empty;
   wire [7:0]					w_putchar_fifo_out;
   wire 					w_putchar_fifo_pop;
   wire [3:0]					w_putchar_fifo_rptr, w_putchar_fifo_wptr;

   // SCC serial Rx: ARM/PS -> S00_AXI -> core Rx FIFO
   wire 					w_scc_rx_push;
   wire [7:0]					w_scc_rx_data;
   wire 					w_scc_rx_full;
   
   assign w_states = {
		      2'd0,
		      w_l2rsp_state,
		      w_inflight,
		      w_axistate, //16
		      w_dstate, //12
		      w_istate, //9
		      w_l2state, //5
		      w_state //0
		      };

   
   assign w_rvstatus = {w_memq_empty,
			2'd0,
			w_istate[2:0],
			w_mem_rsp_valid, 
			w_dstate, //4 bits
			w_mem_req_opcode[3:0], //4 bits
			w_mem_req_valid,
			w_reset_out,
			w_l2state,
			w_state,//6
			1'b0, //5
			w_got_bad_addr, //4
			w_got_ud, //3
			w_got_break, //2
			w_in_flush, //1
			w_ready}; //0

   wire [31:0]					w_last_addr, w_last_data;
   wire [31:0]					w_max_fetches;


   wire [31:0]					w_branch_pc;
   wire						w_branch_val, w_branch_fault;

   wire						w_sgi_mode;
   wire [31:0]					w_status_reg;
   

   
   // ---- SCSI mailbox wires: henry_soc publishes req_*, S00_AXI returns rsp_*/sel_delay ----
   /* Kodiak: the ARM's coherent-read doorbell (arm_snoop) and the IOMMU registers it
    * reads for the DVMA translation */
   wire [31:0]  w_snoop_seq, w_snoop_line, w_snoop_done_seq;
   wire [31:0]  w_iommu_ctrl, w_iommu_base, w_sys_reset_cnt;
   // staging-ring doorbells: S00_AXI (ARM) -> henry_soc engines
   wire [31:0]  w_ring_tx_cons, w_ring_rx_prod, w_ring_scsi_cq_cons, w_ring_scsi_rd_beats, w_ring_scsi_rd_seq;
   // ARM-served GIO window: S00_AXI doorbells <-> henry_soc
   wire [31:0]  w_gio_ans_lo, w_gio_ans_hi, w_gio_ans_seq, w_gio_cons, w_gio_prod, w_gio_pend_seq;
   wire [31:0]  w_vdma_stat0, w_vdma_stat1;   // MC VDMA usage counters (read 0x22/0x23)
   wire [4:0]   w_gfx_perf_sel;               // graphics-path counter select (write 0x24 [4:0])
   wire [31:0]  w_gfx_perf_data;              // selected counter half (read 0x02)
   wire [31:0]  w_ext_irq;
   wire         w_gio_pend;
   // ext flush page list: S00_AXI (ARM writes 0x3C/0x3D) -> henry_soc
   wire         w_ext_pg_push, w_ext_pg_go, w_ext_pg_drop;
   wire [31:0]  w_ext_pg_ppn;
   wire [31:0]  w_scsi_dbg;          // shim debug viz (AXI PMU readback)
   // ---- ENET shim state: henry_soc publishes tx_req/rx_arm for debug readback ----
   wire [31:0]  w_enet_tx_req_seq, w_enet_tx_nbdp, w_enet_rx_arm_seq, w_enet_rx_nbdp;
   axi_is_the_worst_v1_0_S00_AXI # ( .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH), .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH))
   axi_is_the_worst_v1_0_S00_AXI_inst (
				       .controlreg(w_controlreg),
				       .base(w_baseaddr),
				       .mask(w_addrmask),
				       .status(w_status),
				       .last_addr(w_last_addr),
				       .last_data(w_last_data),				       
				       .putchar_fifo_out(w_putchar_fifo_out),
				       .putchar_fifo_empty(w_putchar_fifo_empty),
				       .putchar_fifo_pop(w_putchar_fifo_pop),
				       .putchar_fifo_wptr(w_putchar_fifo_wptr),
				       .putchar_fifo_rptr(w_putchar_fifo_rptr),
				       .scc_rx_push(w_scc_rx_push),
				       .scc_rx_data(w_scc_rx_data),
				       .scc_rx_full(w_scc_rx_full),
				       .control(w_rvcontrol),
				       .resume_pc(w_resume_pc),
				       .bp_pc(w_bp_pc),
				       .bp_wp_addr(w_bp_wp_addr),
				       .bp_wp_val(w_bp_wp_val),
				       .rvstatus(w_rvstatus),
				       .states(w_states),
				       .sgi_mode(w_sgi_mode),				       
				       .epc(w_epc64),
				       .status_reg(w_status_reg),
				       .badvaddr(w_badvaddr64),
				       .wf_epc(w_wf_epc),
				       .wf_badv(w_wf_badv),
				       .wf_stat(w_wf_stat),
				       .cause(w_cause),
				       .dbg_frozen(w_dbg_frozen),
				       .dbg_wp_data(w_dbg_wp_data),
				       .dbg_trace_data(w_trace_data),
				       .dbg_trace_wptr(w_trace_wptr),
				       .dbg_trace_index(w_trace_index),
				       .trace_ring_wptr(r_dbg_rob_p3),  /* reg 0x1C repurposed: {l1d,core} r_rob_inflight */
				       .trace_overflow(w_trace_overflow),
				       .cur_asid(w_cur_asid),
				       .dbg_head_pc(w_dbg_head_pc[31:0]),
				       .dbg_head_status(w_dbg_head_status),
				       .l1i_flush_done(w_l1i_flush_done),
				       .l1d_flush_done(w_l1d_flush_done),
				       .l2_flush_done(w_l2_flush_done),				       
				       .rv_mem_addr(w_axi_addr),
				       .pc(w_pc),
				       .pc2(w_pc2),
				       .pc_valid(w_pc_valid),
				       .pc2_valid(w_pc2_valid),
				       .op(w_op),
				       .op2(w_op2),
				       
				       .branch_pc(w_branch_pc),
				       .branch_pc_valid(w_branch_val),
				       .branch_fault(w_branch_fault),

				       .mem_rsp_valid(w_mem_rsp_valid),
				       .mem_rsp_load_data(w_load_data),
				       .mem_req_addr(w_mem_req_addr),
				       .mem_req_valid(w_mem_req_valid),				       
				       
				       .retire_reg_ptr(w_reg_ptr0),
				       .retire_reg_data(w_reg_data0),
				       .retire_reg_valid(w_reg_val0),
				       .retire_reg_two_ptr(w_reg_ptr1),
				       .retire_reg_two_data(w_reg_data1),
				       .retire_reg_two_valid(w_reg_val1),

				       
				       /* PIPELINED (cnt_pipe, 10 stages) -- see the
					* declarations above.  Upper half is tied to 0
					* because no readback register exposes it; the
					* truncation is explicit, not implicit. */
				       .l1i_cache_accesses(64'd0),
				       .l1i_cache_hits(64'd0),
				       .l1d_cache_accesses(64'd0),
				       .l1d_cache_hits(64'd0),
				       .l2_cache_accesses(64'd0),
				       .l2_cache_hits(64'd0),
				       /*.l2_early_accesses(w_l2_early_accesses), */
				       .branch_faults('d0),
				       .axi_busy(w_axi_busy),				       
				       .dram_req_cnt(w_txn_cnt),
				       .dram_req_cycles(w_txn_lat),
				       .axi_reads(w_axi_reads),
				       .axi_writes(w_axi_writes),
				       .max_fetches(w_max_fetches),
				       .rv_reset(w_rvcontrol[0]),

				       .snoop_done_seq(w_snoop_done_seq),
				       .iommu_ctrl(w_iommu_ctrl),
				       .iommu_base(w_iommu_base),
				       .sys_reset_cnt(w_sys_reset_cnt),
				       .snoop_seq(w_snoop_seq),
				       .snoop_line(w_snoop_line),
				       .ring_tx_cons(w_ring_tx_cons),
				       .ring_rx_prod(w_ring_rx_prod),
				       .ring_scsi_cq_cons(w_ring_scsi_cq_cons),
				       .ring_scsi_rd_beats(w_ring_scsi_rd_beats),
				       .ring_scsi_rd_seq(w_ring_scsi_rd_seq),
				       .gio_ans_lo(w_gio_ans_lo),
				       .gio_ans_hi(w_gio_ans_hi),
				       .gio_ans_seq(w_gio_ans_seq),
				       .gio_cons(w_gio_cons),
				       .ext_irq(w_ext_irq),
				       .gio_prod(w_gio_prod),
				       .vdma_stat0(w_vdma_stat0),
				       .vdma_stat1(w_vdma_stat1),
				       .gfx_perf_sel(w_gfx_perf_sel),
				       .gfx_perf_data(w_gfx_perf_data),
				       .gio_pend(w_gio_pend),
				       .gio_pend_seq(w_gio_pend_seq),
				       .ext_flush_stat(w_ext_flush_stat),
				       .ext_flush_cycles(w_ext_flush_cycles),
				       .ext_pg_push(w_ext_pg_push),
				       .ext_pg_ppn(w_ext_pg_ppn),
				       .ext_pg_go(w_ext_pg_go),
				       .ext_pg_drop(w_ext_pg_drop),
				       .scsi_dbg(w_scsi_dbg),
				       .enet_tx_req_seq(w_enet_tx_req_seq),
				       .enet_tx_nbdp(w_enet_tx_nbdp),
				       .enet_rx_arm_seq(w_enet_rx_arm_seq),
				       .enet_rx_nbdp(w_enet_rx_nbdp),

				       .S_AXI_ACLK(s00_axi_aclk),
				       .S_AXI_ARESETN(s00_axi_aresetn),
				       .S_AXI_AWADDR(s00_axi_awaddr),
				       .S_AXI_AWPROT(s00_axi_awprot),
				       .S_AXI_AWVALID(s00_axi_awvalid),
				       .S_AXI_AWREADY(s00_axi_awready),
				       .S_AXI_WDATA(s00_axi_wdata),
				       .S_AXI_WSTRB(s00_axi_wstrb),
				       .S_AXI_WVALID(s00_axi_wvalid),
				       .S_AXI_WREADY(s00_axi_wready),
				       .S_AXI_BRESP(s00_axi_bresp),
				       .S_AXI_BVALID(s00_axi_bvalid),
				       .S_AXI_BREADY(s00_axi_bready),
				       .S_AXI_ARADDR(s00_axi_araddr),
				       .S_AXI_ARPROT(s00_axi_arprot),
				       .S_AXI_ARVALID(s00_axi_arvalid),
				       .S_AXI_ARREADY(s00_axi_arready),
				       .S_AXI_RDATA(s00_axi_rdata),
				       .S_AXI_RRESP(s00_axi_rresp),
				       .S_AXI_RVALID(s00_axi_rvalid),
				       .S_AXI_RREADY(s00_axi_rready)
				       );

   // Instantiation of Axi Bus Interface M00_AXI

   
   axi_is_the_worst_v1_0_M00_AXI # ( 
				     .C_M_TARGET_SLAVE_BASE_ADDR(0), 
				     .C_M_AXI_BURST_LEN(C_M00_AXI_BURST_LEN),
				     .C_M_AXI_ID_WIDTH(C_M00_AXI_ID_WIDTH), 
				     .C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
				     .C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
				     .C_M_AXI_AWUSER_WIDTH(C_M00_AXI_AWUSER_WIDTH),
				     .C_M_AXI_ARUSER_WIDTH(C_M00_AXI_ARUSER_WIDTH),
				     .C_M_AXI_WUSER_WIDTH(C_M00_AXI_WUSER_WIDTH),
				     .C_M_AXI_RUSER_WIDTH(C_M00_AXI_RUSER_WIDTH),
				     .C_M_AXI_BUSER_WIDTH(C_M00_AXI_BUSER_WIDTH)
				     )
   axi_is_the_worst_v1_0_M00_AXI_inst (
				       .rv_reset(w_rvcontrol[0]),
				       .step_txn(w_rvcontrol[16]),
				       .ack_txn(1'b0),
				       .baseaddr(w_baseaddr),
				       .addrmask(w_addrmask),
				       .cpuaddr(w_mem_req_addr),
				       .txn_lat(w_txn_lat),
				       .txn_cnt(w_txn_cnt),
				       .load_data(w_load_data),
				       .axi_busy(w_axi_busy),
				       .state(w_axistate),
				       .last_addr(w_last_addr),
				       .last_data(w_last_data),
				       .axi_reads(w_axi_reads),
				       .axi_writes(w_axi_writes),
				       .max_fetches(w_max_fetches),		
				       .sgi_mode(1'b0),   /* Kodiak folds its own PAs (the PROM), before M00 */
				       .mem_req_store_data(w_mem_req_store_data),
				       
				       .mem_req_valid(w_mem_req_valid),
				       .mem_req_tag(w_mem_req_tag),
				       .mem_opcode(w_mem_req_opcode),
				       .mem_mask(w_mem_req_mask),
				       .mem_rsp_valid(w_mem_rsp_valid),
				       .mem_rsp_bad(w_mem_rsp_bad),				       				       
				       .mem_rsp_tag(w_mem_rsp_tag),				       
				       .mem_req_gnt(w_mem_req_gnt),
				       .mem2_req_valid(w_mem2_req_valid),
				       .mem2_req_addr(w_mem2_req_addr),
				       .mem2_opcode(w_mem2_req_opcode),
				       .mem2_mask(w_mem2_req_mask),
				       .mem2_req_store_data(w_mem2_req_store_data),
				       .mem2_rsp_valid(w_mem2_rsp_valid),
				       .mem2_rsp_bad(w_mem2_rsp_bad),
				       .mem2_load_data(w_mem2_load_data),
				       .INIT_AXI_TXN(m00_axi_init_axi_txn),
				       .TXN_DONE(m00_axi_txn_done),
				       .ERROR(m00_axi_error),
				       .M_AXI_ACLK(m00_axi_aclk),
				       .M_AXI_ARESETN(m00_axi_aresetn),
				       .M_AXI_AWID(m00_axi_awid),
				       .M_AXI_AWADDR(m00_axi_awaddr),
				       .M_AXI_AWLEN(m00_axi_awlen),
				       .M_AXI_AWSIZE(m00_axi_awsize),
				       .M_AXI_AWBURST(m00_axi_awburst),
				       .M_AXI_AWLOCK(m00_axi_awlock),
				       .M_AXI_AWCACHE(m00_axi_awcache),
				       .M_AXI_AWPROT(m00_axi_awprot),
				       .M_AXI_AWQOS(m00_axi_awqos),
				       .M_AXI_AWUSER(m00_axi_awuser),
				       .M_AXI_AWVALID(m00_axi_awvalid),
				       .M_AXI_AWREADY(m00_axi_awready),
				       .M_AXI_WDATA(m00_axi_wdata),
				       .M_AXI_WSTRB(m00_axi_wstrb),
				       .M_AXI_WLAST(m00_axi_wlast),
				       .M_AXI_WUSER(m00_axi_wuser),
				       .M_AXI_WVALID(m00_axi_wvalid),
				       .M_AXI_WREADY(m00_axi_wready),
				       .M_AXI_BID(m00_axi_bid),
				       .M_AXI_BRESP(m00_axi_bresp),
				       .M_AXI_BUSER(m00_axi_buser),
				       .M_AXI_BVALID(m00_axi_bvalid),
				       .M_AXI_BREADY(m00_axi_bready),
				       .M_AXI_ARID(m00_axi_arid),
				       .M_AXI_ARADDR(m00_axi_araddr),
				       .M_AXI_ARLEN(m00_axi_arlen),
				       .M_AXI_ARSIZE(m00_axi_arsize),
				       .M_AXI_ARBURST(m00_axi_arburst),
				       .M_AXI_ARLOCK(m00_axi_arlock),
				       .M_AXI_ARCACHE(m00_axi_arcache),
				       .M_AXI_ARPROT(m00_axi_arprot),
				       .M_AXI_ARQOS(m00_axi_arqos),
				       .M_AXI_ARUSER(m00_axi_aruser),
				       .M_AXI_ARVALID(m00_axi_arvalid),
				       .M_AXI_ARREADY(m00_axi_arready),
				       .M_AXI_RID(m00_axi_rid),
				       .M_AXI_RDATA(m00_axi_rdata),
				       .M_AXI_RRESP(m00_axi_rresp),
				       .M_AXI_RLAST(m00_axi_rlast),
				       .M_AXI_RUSER(m00_axi_ruser),
				       .M_AXI_RVALID(m00_axi_rvalid),
				       .M_AXI_RREADY(m00_axi_rready)
				       );

   // Add user logic here


   
   
   wire [31:0] w_ext_flush_stat;     // henry_soc -> S00_AXI read 0x25 [31:1]
   wire [31:0] w_ext_flush_cycles;   // henry_soc -> S00_AXI read 0x24 [31:1]
   // SoC-level integration: kodiak_soc, the SPARCstation 20 (the superdupersparc
   // core + the SLAVIO misc/timer/interrupt-controller, ECC and IOMMU registers in
   // RTL).  RAM and the boot PROM go out on lane 0 of the M00 master; every other
   // device is served by software on the ARM through the window (arm_window.sv,
   // the GIO-window doorbells 0x20-0x23 and its ring on lane 1).  The ARM's C++
   // models raise interrupts through ext_irq (write 0x2a) and read guest RAM
   // coherently with the snoop doorbell (arm_snoop.sv).
   //
   // DRAM layout (offsets from base, write 0x06, in the 496 MB the kernel reserves;
   // mask, write 0x08, = 496 MB - 1):
   //   0x00000000  guest RAM, pa = offset (kodiak_soc's RAM_BYTES, 256 MB)
   //   0x1d000000  the boot PROM, 1 MB (the ARM loads OBP here), pa 0xff00xxxxx
   //   0x1e000000  the window's staging region (prod at +0x60, the ring at +0x200000)
   // so the lane-0 fold below maps the PROM; RAM and the staging region pass through.
   wire [35:0] w_soc_mem_req_addr;
   assign w_mem_req_addr = (w_soc_mem_req_addr[35:20] == 16'hff00) ?
			   {16'h01d0, w_soc_mem_req_addr[19:0]} : w_soc_mem_req_addr;
   wire w_snoop_req_valid, w_snoop_req_ack, w_snoop_req_wbinv, w_snoop_done;
   wire [35:0] w_snoop_req_addr;

   arm_snoop armsnoop0
     (
      .clk(s00_axi_aclk),
      .reset(w_reset | w_rvcontrol[0]),
      .line(w_snoop_line),
      .seq(w_snoop_seq),
      .done_seq(w_snoop_done_seq),
      .snoop_req_valid(w_snoop_req_valid),
      .snoop_req_addr(w_snoop_req_addr),
      .snoop_req_wbinv(w_snoop_req_wbinv),
      .snoop_req_ack(w_snoop_req_ack),
      .snoop_done(w_snoop_done)
      );

   kodiak_soc
     kodiaksoc0 (
		 .clk(s00_axi_aclk),
		 .reset(w_reset | w_rvcontrol[0]),
		 .retire_allowed(1'b1),
		 .single_step(w_rvcontrol[31]),
		 .bp_enable(w_rvcontrol[17]),
		 .fault_clear(w_rvcontrol[18]),
		 .bp_pc(w_bp_pc),
		 .bp_wp_addr(w_bp_wp_addr),
		 .bp_wp_val(w_bp_wp_val),
		 .bp_fault_only(w_rvcontrol[19]),
		 .rt_oneshot(w_rvcontrol[22]),
		 .l2_nocache(w_rvcontrol[20]),
		 .step(w_rvcontrol[30]),
		 .in_flush_mode(w_in_flush),
		 .resume(w_rvcontrol[1]),
		 .resume_pc(w_resume_pc),
		 .ready_for_resume(w_ready),
		 .mem_req_valid(w_mem_req_valid),
		 .mem_req_addr(w_soc_mem_req_addr),
		 .mem_req_store_data(w_mem_req_store_data),
		 .mem_req_opcode(w_mem_req_opcode),
		 .mem_req_mask(w_mem_req_mask),
		 .mem_req_uncached(),
		 .mem_rsp_valid(w_mem_rsp_valid),
		 .mem_rsp_bad(w_mem_rsp_bad),
		 .mem_rsp_load_data(w_load_data),
		 .retire_fp_reg_ptr(),
		 .retire_fp_reg_data(),
		 .retire_fp_reg_valid(),
		 .retire_fp_reg_two_ptr(),
		 .retire_fp_reg_two_data(),
		 .retire_fp_reg_two_valid(),
		 .retire_fcr_reg_ptr(),
		 .retire_fcr_reg_data(),
		 .retire_fcr_reg_valid(),
		 .retire_fcr_reg_two_ptr(),
		 .retire_fcr_reg_two_data(),
		 .retire_fcr_reg_two_valid(),
		 .retire_load_addr(),
		 .retire_load_addr_two(),
		 .wf_epc(w_wf_epc),
		 .wf_badv(w_wf_badv),
		 .wf_stat(w_wf_stat),
		 .retire_reg_ptr(),
		 .retire_reg_data(),
		 .retire_reg_valid(),
		 .retire_reg_two_ptr(),
		 .retire_reg_two_data(),
		 .retire_reg_two_valid(),
		 .retire_y_valid(),
		 .retire_y_data(),
		 .retire_valid(w_pc_valid),
		 .retire_two_valid(w_pc2_valid),
		 .retire_pc(w_pc),
		 .retire_two_pc(w_pc2),
		 .retire_op(),
		 .retire_two_op(),
		 .branch_pc(),
		 .branch_pc_valid(),
		 .branch_fault(),
		 .l1i_cache_accesses(w_l1i_cache_accesses),
		 .l1i_cache_hits(w_l1i_cache_hits),
		 .l1d_cache_accesses(w_l1d_cache_accesses),
		 .l1d_cache_hits(w_l1d_cache_hits),
		 .l2_cache_accesses(w_l2_cache_accesses),
		 .l2_cache_hits(w_l2_cache_hits),
		 .got_break(w_got_break),
		 .ext_irq(w_ext_irq),
		 .trap_taken(),
		 .trap_taken_tt(),
		 .trap_taken_pc(),
		 .got_ud(w_got_ud),
		 .got_bad_addr(w_got_bad_addr),
		 .core_state(w_state),
		 .l1i_state(w_istate),
		 .l1d_state(w_dstate),
		 .l2_state(w_l2state),
		 .l2_rsp_state(w_l2rsp_state),
		 .inflight(w_inflight),
		 .dbg_rob_inflight(w_dbg_rob_inflight),
		 .epc(w_epc64[31:0]),
		 .dbg_frozen(w_dbg_frozen),
		 .dbg_wp_data(w_dbg_wp_data),
		 .l1i_flush_done(w_l1i_flush_done),
		 .l1d_flush_done(w_l1d_flush_done),
		 .l2_flush_done(w_l2_flush_done),
		 .ext_flush_req(1'b0),
		 .ext_flush_done(),
		 .ext_flush_ppn(24'd0),
		 .ext_flush_whole(1'b0),
		 .ext_flush_drop(1'b0),
		 .ext_flush_dirty_cnt(),
		 .dbg_flush(),
		 .dma_inval_req(1'b0),
		 .dma_inval_addr(36'd0),
		 .dma_inval_ack(),
		 .snoop_req_valid(w_snoop_req_valid),
		 .snoop_req_addr(w_snoop_req_addr),
		 .snoop_req_ack(w_snoop_req_ack),
		 .snoop_req_wbinv(w_snoop_req_wbinv),
		 .snoop_done(w_snoop_done),
		 .mem2_req_valid(w_mem2_req_valid),
		 .mem2_req_addr(w_mem2_req_addr),
		 .mem2_req_opcode(w_mem2_req_opcode),
		 .mem2_req_store_data(w_mem2_req_store_data),
		 .mem2_req_mask(w_mem2_req_mask),
		 .mem2_rsp_valid(w_mem2_rsp_valid),
		 .win_cons(w_gio_cons),
		 .win_ans_lo(w_gio_ans_lo),
		 .win_ans_hi(w_gio_ans_hi),
		 .win_ans_seq(w_gio_ans_seq),
		 .win_prod(w_gio_prod),
		 .win_pend(w_gio_pend),
		 .win_pend_seq(w_gio_pend_seq),
		 .iommu_ctrl(w_iommu_ctrl),
		 .iommu_base(w_iommu_base),
		 .sys_reset_cnt(w_sys_reset_cnt),
		 .dbg_head_pc(w_dbg_head_pc[31:0]),
		 .dbg_head_status(w_dbg_head_status),
		 .dbg_head_fetch_cycle(),
		 .dbg_head_alloc_cycle(),
		 .dbg_serialize_cycle(),
		 .dbg_cycle(),
		 .dbg_oldest_first_pending(),
		 .dbg_trace_index(w_trace_index),
		 .dbg_trace_data(w_trace_data),
		 .dbg_trace_wptr(w_trace_wptr)
		 );

   // tie-offs for the Henry status/debug taps and devices Kodiak does not have
   assign w_dbg_head_pc[63:32] = 32'd0;
   assign w_epc64[63:32] = 32'd0;
   assign w_badvaddr64 = 64'd0;
   assign w_status_reg = 32'd0;
   assign w_cause = 5'd0;
   assign w_cur_asid = 8'd0;
   assign w_trace_overflow = 1'b0;
   assign w_trace_ring_wptr = 32'd0;
   assign w_reg_ptr0 = 5'd0;
   assign w_reg_ptr1 = 5'd0;
   assign w_reg_data0 = 32'd0;
   assign w_reg_data1 = 32'd0;
   assign w_reg_val0 = 1'b0;
   assign w_reg_val1 = 1'b0;
   assign w_putchar_fifo_out = 8'd0;
   assign w_putchar_fifo_empty = 1'b1;
   assign w_putchar_fifo_wptr = 4'd0;
   assign w_putchar_fifo_rptr = 4'd0;
   assign w_ring_tx_cons = 32'd0;
   assign w_ring_rx_prod = 32'd0;
   assign w_vdma_stat0 = 32'd0;
   assign w_vdma_stat1 = 32'd0;
   assign w_gfx_perf_data = 32'd0;
   assign w_ext_flush_stat = 32'd0;
   assign w_ext_flush_cycles = 32'd0;
   assign w_scsi_dbg = 32'd0;
   assign w_enet_tx_req_seq = 32'd0;
   assign w_enet_tx_nbdp = 32'd0;
   assign w_enet_rx_arm_seq = 32'd0;
   assign w_enet_rx_nbdp = 32'd0;
   assign w_op             = 7'd0;
   assign w_op2            = 7'd0;
   assign w_branch_pc      = 32'd0;
   assign w_branch_val     = 1'b0;
   assign w_branch_fault   = 1'b0;

endmodule

/* cnt_pipe -- N-stage register pipeline for a wide debug-counter bus.
 *
 * Lives in THIS file on purpose: the IP's component.xml lists exactly four
 * source files, so a new cnt_pipe.v would be copied into hdl/ by
 * gen_mipscore.sh and then silently NOT compiled -- synthesis would fail on an
 * unresolved module.  Keeping it here means internal RTL edits still never
 * require re-packaging the IP.
 *
 * WHY IT EXISTS: the cache performance counters (l1i/l1d/l2 accesses and hits)
 * live deep inside the caches and feed a 64-entry AXI readback mux at the chip
 * edge -- a long route into wide combinational select logic, historically a
 * major source of timing pressure here.  Software samples these at Hz rates, so
 * latency is entirely free; pipelining lets the placer/router turn one long hop
 * into N short ones.
 *
 * THE ATTRIBUTES ARE NOT OPTIONAL.  A flop chain with no logic between stages is
 * precisely what Vivado's SRL inference targets: it packs all N stages into one
 * SRL16/SRL32 inside a SINGLE LUT at a SINGLE site.  That simulates identically
 * and reports the same latency while completely defeating the purpose, because
 * the long route remains a single hop into the SRL.  Both attributes are needed
 * -- shreg_extract disables the inference, srl_style pins the implementation to
 * real registers.  Verify it held: "LUT as Memory" in the utilization report
 * must NOT grow when this is added (6 * 32 * 10 = 1920 new FFs instead).
 */
module cnt_pipe(clk, in, out);
   parameter W = 32;
   parameter N = 10;
   input wire 		clk;
   input wire [W-1:0] 	in;
   output wire [W-1:0] 	out;

   (* shreg_extract = "no", srl_style = "register" *)
   reg [W-1:0] 		r_pipe [N-1:0];

   integer 		i;
   always @(posedge clk)
     begin
	r_pipe[0] <= in;
	for(i = 1; i < N; i = i + 1)
	  begin
	     r_pipe[i] <= r_pipe[i-1];
	  end
     end // always

   assign out = r_pipe[N-1];
endmodule // cnt_pipe
