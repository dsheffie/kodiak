`include "machine.vh"
// -----------------------------------------------------------------------------
// arm_window.sv -- device space served by software on the ARM (Henry's
// gio_window, re-targeted to Kodiak's devices that are not in RTL yet: the ZS
// serial ports, the NVRAM, the ESP, the Lance, ...; ss10sim's sun4m C++ models
// run on the ARM).
//
// Every CPU access the SoC sends here becomes a 16-byte record in a capture
// ring in the staging region:
//   STORE : posted -- the CPU continues as soon as the record is queued.
//   READ  : the CPU load is held until the ARM writes the answer and then its
//           sequence number (ans_lo, ans_hi, then ans_seq).  The record goes
//           through the same ring, so the ARM sees it after every earlier store.
//   ATOMIC: an ldstub or swap: held as a READ; the ARM reads the old value,
//           answers it, then writes the record's data under its mask.
// Record (LE, byte i = bits [8i+7:8i]):
//   [20:0]   recno[20:0] -- records are numbered 1, 2, 3, ...
//   [53:21]  pa[35:3]: the doubleword
//   [61:54]  byte mask: lane i = the byte at pa + i
//   [63:62]  type: 0 STORE, 1 READ, 2 ATOMIC
//   [127:64] lane[0..7]: the store data (zero for a READ)
// The answer: ans_lo = lanes 0-3, ans_hi = lanes 4-7; ans_seq = {bus error,
// retry, 9'd0, recno[20:0]}.  A bus error answers the access as a bad response
// (the empty-slot probes in OBP depend on it); a posted store has no answer.
// Retry is a NACK (an MBus relinquish-and-retry): the ARM needs to snoop the
// core's caches for a DMA, which the L2 cannot do while it waits for this
// load, so the load is answered "retry" (no data) and re-issued by the L2;
// the ARM drops the NACKed record unperformed.
// Ring slot of record n = (n-1) mod RING_N.  prod (records written, LE u32) is
// published at PROD_PA after every READ/ATOMIC record, whenever the queue
// drains, and at least every PROD_EVERY records.  The CPU is held while the
// ring is full (assigned - cons == RING_N).
// One memory port, to the staging region (not snooped).  When the queue holds
// 4 records and the next slot is 64B-aligned, they go out as one 64B burst
// write (opcode 6); otherwise one 16B write per record.
// -----------------------------------------------------------------------------
module arm_window #(parameter logic [31:0] RING_PA    = 32'h1e200000,
		    parameter int          LG_RING_N  = 16,             // 65536 x 16 B
		    parameter logic [31:0] PROD_PA    = 32'h1e000060,
		    parameter int          PROD_EVERY = 32)
   (input  logic                  clk,
    input  logic                  reset,
    // ---- CPU side (kodiak_soc's device FSM) ----
    input  logic                  sel,            // 1-cycle: accept this access
    input  logic [4:0]            opcode,         // 4 load, 7 store, 8 ldstub, 9 swap
    input  logic [`PA_WIDTH-1:0]  addr,           // 16-byte aligned (the mask selects bytes)
    input  logic [15:0]           mask,
    input  logic [127:0]          wdata,
    output logic                  done,           // 1-cycle: the access is complete
    output logic                  bad,            // with done: a bus error
    output logic                  retry,          // with done: NACKed (re-issue the access)
    output logic [127:0]          rdata,          // valid with done (loads)
    // ---- ARM doorbells (S00_AXI) ----
    input  logic [31:0]           cons,           // records the ARM has consumed
    input  logic [31:0]           ans_lo,         // answer lanes 0-3
    input  logic [31:0]           ans_hi,         // answer lanes 4-7
    input  logic [31:0]           ans_seq,        // {bus error, retry, 9'd0, recno[20:0]}
    // ---- debug readback ----
    output logic [31:0]           prod,
    output logic                  pend,
    output logic [31:0]           pend_seq,
    // ---- one memory port (the staging region) ----
    output logic                  mem_req_valid,
    output logic [`PA_WIDTH-1:0]  mem_req_addr,
    output logic [4:0]            mem_req_opcode,
    output logic [511:0]          mem_req_store_data,  // [127:0] for a 16B write, all 64B for a burst
    output logic [15:0]           mem_req_mask,
    input  logic                  mem_rsp_valid);

   localparam int RING_N = 1 << LG_RING_N;
   localparam int QN     = 4;            // queued records not yet in memory

   typedef enum logic [1:0] {W_IDLE = 2'd0, W_REC = 2'd1, W_PROD = 2'd2, W_BURST = 2'd3} wstate_t;

   // ---- record queue ----
   logic [127:0] r_q [QN-1:0];
   logic [1:0]   r_q_head, n_q_head, r_q_tail, n_q_tail;
   logic [2:0]   r_q_cnt, n_q_cnt;

   // ---- CPU side ----
   logic         r_held, n_held;          // an accepted access not yet queued
   logic [127:0] r_held_rec, n_held_rec;
   logic         r_held_rd, n_held_rd;    // a READ or ATOMIC: waits for an answer
   logic         r_wait, n_wait;          // a READ/ATOMIC is queued, waiting for its answer
   logic [31:0]  r_wait_seq, n_wait_seq;
   logic [31:0]  r_assigned, n_assigned;  // recno of the last record built
   logic         r_done, n_done;
   logic         r_bad, n_bad;
   logic         r_retry, n_retry;
   logic [127:0] r_rdata, n_rdata;

   // ---- writer ----
   wstate_t      r_wstate, n_wstate;
   logic [31:0]  r_written, n_written;    // records in memory
   logic [31:0]  r_published, n_published;
   logic         r_rd_unpub, n_rd_unpub;  // a READ/ATOMIC record is written but prod not yet published

   logic [127:0] t_rec;
   logic [7:0]   t_lanes_mask;
   logic [63:0]  t_lanes;
   logic         t_store, t_atomic;
   logic         t_space, t_enq, t_deq, t_deq4;
   logic [127:0] t_enq_rec;
   logic [31:0]  t_slot;
   logic [31:0]  t_ring_addr, t_prod_addr;

   assign done           = r_done;
   assign bad            = r_bad;
   assign retry          = r_retry;
   assign rdata          = r_rdata;
   assign prod           = r_published;
   assign pend           = r_wait;
   assign pend_seq       = r_wait_seq;

   /* a record that waits for an answer (type READ or ATOMIC) */
   function logic rec_waits(input logic [127:0] rec);
      rec_waits = (rec[63:62] != 2'b00);
   endfunction

   always_comb
     begin
	/* the CPU's doubleword: the core issues at most 8 bytes, in one half of the line */
	t_store      = (opcode == 5'd7);
	t_atomic     = (opcode == 5'd8) | (opcode == 5'd9);
	t_lanes_mask = (|mask[15:8]) ? mask[15:8] : mask[7:0];
	t_lanes      = (|mask[15:8]) ? wdata[127:64] : wdata[63:0];
	t_rec        = {(t_store | t_atomic) ? t_lanes : 64'd0,   /* a READ carries no data */
			t_store ? 2'b00 : (t_atomic ? 2'b10 : 2'b01),
			t_lanes_mask,
			addr[`PA_WIDTH-1:4], |mask[15:8],   /* addr is line aligned: the mask picks the half */
			21'(r_assigned + 32'd1)};
	/* ring space counts every record built so far, queued or written */
	t_space = (r_assigned - cons) < 32'(RING_N);

	n_held      = r_held;
	n_held_rec  = r_held_rec;
	n_held_rd   = r_held_rd;
	n_wait      = r_wait;
	n_wait_seq  = r_wait_seq;
	n_assigned  = r_assigned;
	n_done      = 1'b0;
	n_bad       = 1'b0;
	n_retry     = 1'b0;
	n_rdata     = r_rdata;
	t_enq       = 1'b0;
	t_enq_rec   = t_rec;

	if(sel)
	  begin
	     /* a new access: queue it now (recno = assigned + 1), or hold it */
	     if((r_q_cnt != 3'(QN)) && t_space)
	       begin
		  n_assigned = r_assigned + 32'd1;
		  t_enq = 1'b1;
		  if(t_store)
		    begin
		       n_done = 1'b1;          /* posted */
		    end
		  else
		    begin
		       n_wait     = 1'b1;
		       n_wait_seq = r_assigned + 32'd1;
		    end
	       end
	     else
	       begin
		  n_held     = 1'b1;
		  n_held_rec = t_rec;
		  n_held_rd  = !t_store;
	       end
	  end
	else if(r_held)
	  begin
	     if((r_q_cnt != 3'(QN)) && t_space)
	       begin
		  /* the held record takes its recno now */
		  n_assigned = r_assigned + 32'd1;
		  t_enq      = 1'b1;
		  t_enq_rec  = {r_held_rec[127:21], 21'(r_assigned + 32'd1)};
		  n_held     = 1'b0;
		  if(r_held_rd)
		    begin
		       n_wait     = 1'b1;
		       n_wait_seq = r_assigned + 32'd1;
		    end
		  else
		    begin
		       n_done = 1'b1;
		    end
	       end
	  end

	if(r_wait && (ans_seq[20:0] == r_wait_seq[20:0]))
	  begin
	     n_wait  = 1'b0;
	     n_done  = 1'b1;
	     n_bad   = ans_seq[31];
	     n_retry = ans_seq[30];
	     n_rdata = {ans_hi, ans_lo, ans_hi, ans_lo};
	  end
     end // always_comb

   // ---- writer: queue head -> ring slot, then publish prod when due ----
   always_comb
     begin
	n_wstate    = r_wstate;
	n_written   = r_written;
	n_published = r_published;
	n_rd_unpub  = r_rd_unpub;
	t_deq       = 1'b0;
	t_deq4      = 1'b0;
	t_slot      = r_written & 32'(RING_N - 1);   /* record r_written+1 goes to slot r_written */
	t_ring_addr = RING_PA + (t_slot << 4);
	t_prod_addr = PROD_PA & ~32'hf;
	mem_req_valid      = 1'b0;
	mem_req_addr       = '0;
	mem_req_opcode     = 5'd7;
	mem_req_store_data = '0;
	mem_req_mask       = 16'hffff;
	case(r_wstate)
	  W_IDLE:
	    begin
	       if((r_published != r_written) &&
		  (r_rd_unpub || (r_q_cnt == 3'd0) || ((r_written - r_published) >= 32'(PROD_EVERY))))
		 begin
		    n_wstate = W_PROD;
		 end
	       else if((r_q_cnt == 3'(QN)) && (r_written[1:0] == 2'd0))
		 begin
		    n_wstate = W_BURST;       /* 4 records filling one 64B ring line */
		 end
	       else if(r_q_cnt != 3'd0)
		 begin
		    n_wstate = W_REC;
		 end
	    end
	  W_REC:
	    begin
	       mem_req_valid      = 1'b1;
	       mem_req_addr       = `PA_WIDTH'(t_ring_addr);
	       mem_req_store_data = {384'd0, r_q[r_q_head]};
	       if(mem_rsp_valid)
		 begin
		    t_deq     = 1'b1;
		    n_written = r_written + 32'd1;
		    if(rec_waits(r_q[r_q_head]))
		      begin
			 n_rd_unpub = 1'b1;
		      end
		    n_wstate = W_IDLE;
		 end
	    end
	  W_PROD:
	    begin
	       mem_req_valid      = 1'b1;
	       mem_req_addr       = `PA_WIDTH'(t_prod_addr);
	       mem_req_store_data = {384'd0, {96'd0, r_written} << (8 * PROD_PA[3:0])};
	       mem_req_mask       = 16'h000f << PROD_PA[3:0];
	       if(mem_rsp_valid)
		 begin
		    n_published = r_written;
		    n_rd_unpub  = 1'b0;
		    n_wstate    = W_IDLE;
		 end
	    end
	  W_BURST:
	    begin
	       mem_req_valid      = 1'b1;
	       mem_req_addr       = `PA_WIDTH'(t_ring_addr);   /* slot % 4 == 0: 64B-aligned */
	       mem_req_opcode     = 5'd6;
	       mem_req_store_data = {r_q[r_q_head + 2'd3], r_q[r_q_head + 2'd2],
				     r_q[r_q_head + 2'd1], r_q[r_q_head]};
	       if(mem_rsp_valid)
		 begin
		    t_deq4    = 1'b1;
		    n_written = r_written + 32'd4;
		    if(rec_waits(r_q[r_q_head]) || rec_waits(r_q[r_q_head + 2'd1]) ||
		       rec_waits(r_q[r_q_head + 2'd2]) || rec_waits(r_q[r_q_head + 2'd3]))
		      begin
			 n_rd_unpub = 1'b1;
		      end
		    n_wstate = W_IDLE;
		 end
	    end
	  default:
	    begin
	       n_wstate = W_IDLE;
	    end
	endcase // case (r_wstate)

	n_q_head = t_deq4 ? r_q_head : (t_deq ? (r_q_head + 2'd1) : r_q_head);   /* +4 wraps to itself */
	n_q_tail = t_enq ? (r_q_tail + 2'd1) : r_q_tail;
	n_q_cnt  = r_q_cnt + (t_enq ? 3'd1 : 3'd0) - (t_deq ? 3'd1 : 3'd0) - (t_deq4 ? 3'd4 : 3'd0);
     end // always_comb

   always_ff@(posedge clk)
     begin
	if(t_enq)
	  begin
	     r_q[r_q_tail] <= t_enq_rec;
	  end
     end // always_ff

   always_ff@(posedge clk)
     begin
	if(reset)
	  begin
	     r_q_head    <= '0;
	     r_q_tail    <= '0;
	     r_q_cnt     <= '0;
	     r_held      <= 1'b0;
	     r_held_rec  <= '0;
	     r_held_rd   <= 1'b0;
	     r_wait      <= 1'b0;
	     r_wait_seq  <= '0;
	     r_assigned  <= '0;
	     r_done      <= 1'b0;
	     r_bad       <= 1'b0;
	     r_retry     <= 1'b0;
	     r_rdata     <= '0;
	     r_wstate    <= W_IDLE;
	     r_written   <= '0;
	     r_published <= '0;
	     r_rd_unpub  <= 1'b0;
	  end
	else
	  begin
	     r_q_head    <= n_q_head;
	     r_q_tail    <= n_q_tail;
	     r_q_cnt     <= n_q_cnt;
	     r_held      <= n_held;
	     r_held_rec  <= n_held_rec;
	     r_held_rd   <= n_held_rd;
	     r_wait      <= n_wait;
	     r_wait_seq  <= n_wait_seq;
	     r_assigned  <= n_assigned;
	     r_done      <= n_done;
	     r_bad       <= n_bad;
	     r_retry     <= n_retry;
	     r_rdata     <= n_rdata;
	     r_wstate    <= n_wstate;
	     r_written   <= n_written;
	     r_published <= n_published;
	     r_rd_unpub  <= n_rd_unpub;
	  end
     end // always_ff

endmodule // arm_window
