`include "machine.vh"
// -----------------------------------------------------------------------------
// arm_snoop.sv -- a coherent read for software on the ARM: before the ARM reads
// a line of guest RAM directly from DRAM (an IOMMU page-table entry, for the
// DVMA translation it does), it has the L2 snoop the line out of the core's
// caches -- WBINV: a dirty copy is written back, both levels are invalidated --
// so DRAM holds the latest data.  Real SS-20 IOMMU table fetches are coherent
// (the MBus snoops the Viking caches), so an OS may not flush an IOPTE it wrote.
//
// Doorbell (S00_AXI): the ARM writes line = pa[35:4], then a new seq.  When seq
// differs from done_seq, one snoop of that line runs; done_seq = seq when it is
// complete, and the ARM may then read the line.  One snoop at a time, with the
// L2's handshake: snoop_req_valid held until snoop_req_ack, then snoop_done.
// -----------------------------------------------------------------------------
module arm_snoop(clk, reset, line, seq, done_seq,
		 snoop_req_valid, snoop_req_addr, snoop_req_wbinv, snoop_req_ack, snoop_done);
   input logic clk;
   input logic reset;
   input logic [31:0] line;
   input logic [31:0] seq;
   output logic [31:0] done_seq;
   output logic snoop_req_valid;
   output logic [`PA_WIDTH-1:0] snoop_req_addr;
   output logic snoop_req_wbinv;
   input logic snoop_req_ack;
   input logic snoop_done;

   typedef enum logic [1:0] {S_IDLE = 2'd0, S_REQ = 2'd1, S_WAIT = 2'd2} state_t;

   state_t r_state;
   state_t n_state;
   logic [31:0] r_line;
   logic [31:0] n_line;
   logic [31:0] r_seq;
   logic [31:0] n_seq;
   logic [31:0] r_done_seq;
   logic [31:0] n_done_seq;

   always_comb
     begin
	n_state = r_state;
	n_line = r_line;
	n_seq = r_seq;
	n_done_seq = r_done_seq;
	case(r_state)
	  S_IDLE:
	    begin
	       if(seq != r_done_seq)
		 begin
		    n_line = line;
		    n_seq = seq;
		    n_state = S_REQ;
		 end
	    end
	  S_REQ:
	    begin
	       if(snoop_req_ack)
		 begin
		    n_state = S_WAIT;
		 end
	    end
	  S_WAIT:
	    begin
	       if(snoop_done)
		 begin
		    n_done_seq = r_seq;
		    n_state = S_IDLE;
		 end
	    end
	  default:
	    begin
	       n_state = S_IDLE;
	    end
	endcase // case (r_state)
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_state <= S_IDLE;
	     r_line <= 32'd0;
	     r_seq <= 32'd0;
	     r_done_seq <= 32'd0;
	  end
	else
	  begin
	     r_state <= n_state;
	     r_line <= n_line;
	     r_seq <= n_seq;
	     r_done_seq <= n_done_seq;
	  end
     end // always_ff

   assign done_seq = r_done_seq;
   assign snoop_req_valid = (r_state == S_REQ);
   assign snoop_req_addr = {r_line, 4'd0};
   assign snoop_req_wbinv = 1'b1;

endmodule // arm_snoop
