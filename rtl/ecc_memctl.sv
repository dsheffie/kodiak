// -----------------------------------------------------------------------------
// ecc_memctl.sv -- the SS-20 memory controller's register file at
// 0xf00000000 (qemu eccmemctl.c, SMC version; ss10sim sun4m.cc is the
// reference model).  Nine words:
//   0 MER   memory enable   version 0x20000000 | the written bits 0xbff
//   1 MDR   memory delay    31 bits, reset 0x20
//   2 MFSR  fault status    plain
//   3 VCR   video config    plain
//   4 MFAR0 fault address   0x07c00000, writes ignored
//   5 MFAR1 fault address   0, writes ignored
//   6 DR    diagnostic      plain
//   7 ECR0  event count     plain
//   8 ECR1                  alias of ECR0
// No memory errors are ever detected, so the fault registers never change
// and the interrupt is never raised.  The SMC has no diagnostic window.
//
// Register-slave interface as Henry's devices.  Word w of the line is lanes
// 4w..4w+3, big-endian; each masked word is one register access.  The SoC
// sends lines 0 and 1 and the first word of line 2 here.
// -----------------------------------------------------------------------------
`include "machine.vh"

module ecc_memctl(clk, reset, sel, is_store, addr, mask, wdata, rdata);
   input logic clk;
   input logic reset;
   input logic sel;
   input logic is_store;
   input logic [`PA_WIDTH-1:0] addr;
   input logic [15:0] mask;
   input logic [127:0] wdata;
   output logic [127:0] rdata;

   localparam ECC_VERSION = 32'h20000000;
   localparam MFAR0_VALUE = 32'h07c00000;

   logic [11:0] r_mer;
   logic [30:0] r_mdr;
   logic [31:0] r_mfsr;
   logic [31:0] r_vcr;
   logic [31:0] r_dr;
   logic [31:0] r_ecr;

   logic [11:0] n_mer;
   logic [30:0] n_mdr;
   logic [31:0] n_mfsr;
   logic [31:0] n_vcr;
   logic [31:0] n_dr;
   logic [31:0] n_ecr;

   logic [3:0]	t_r;
   logic [31:0] t_v;
   logic [31:0] t_wv;
   integer	w;

   function logic [31:0] be_word(input logic [127:0] d, input integer w);
      logic [31:0] x;
      x = d[32*w +: 32];
      be_word = {x[7:0], x[15:8], x[23:16], x[31:24]};
   endfunction

   always_comb
     begin
	rdata = 128'd0;
	n_mer = r_mer;
	n_mdr = r_mdr;
	n_mfsr = r_mfsr;
	n_vcr = r_vcr;
	n_dr = r_dr;
	n_ecr = r_ecr;
	t_r = 4'd0;
	t_v = 32'd0;
	t_wv = 32'd0;
	for(w = 0; w < 4; w = w + 1)
	  begin
	     t_r = {addr[5:4], 2'(w)};
	     t_wv = be_word(wdata, w);
	     t_v = (t_r == 4'd0) ? (ECC_VERSION | {20'd0, r_mer}) :
		   (t_r == 4'd1) ? {1'b0, r_mdr} :
		   (t_r == 4'd2) ? r_mfsr :
		   (t_r == 4'd3) ? r_vcr :
		   (t_r == 4'd4) ? MFAR0_VALUE :
		   (t_r == 4'd6) ? r_dr :
		   ((t_r == 4'd7) | (t_r == 4'd8)) ? r_ecr :
		   32'd0;
	     if(sel & mask[4*w])
	       begin
		  rdata[32*w +: 32] = {t_v[7:0], t_v[15:8], t_v[23:16], t_v[31:24]};
		  if(is_store)
		    begin
		       if(t_r == 4'd0)
			 begin
			    n_mer = t_wv[11:0] & 12'hbff;
			 end
		       else if(t_r == 4'd1)
			 begin
			    n_mdr = t_wv[30:0];
			 end
		       else if(t_r == 4'd2)
			 begin
			    n_mfsr = t_wv;
			 end
		       else if(t_r == 4'd3)
			 begin
			    n_vcr = t_wv;
			 end
		       else if(t_r == 4'd6)
			 begin
			    n_dr = t_wv;
			 end
		       else if((t_r == 4'd7) | (t_r == 4'd8))
			 begin
			    n_ecr = t_wv;
			 end
		    end
	       end
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_mer <= 12'd0;
	     r_mdr <= 31'h20;
	     r_mfsr <= 32'd0;
	     r_vcr <= 32'd0;
	     r_dr <= 32'd0;
	     r_ecr <= 32'd0;
	  end
	else
	  begin
	     r_mer <= n_mer;
	     r_mdr <= n_mdr;
	     r_mfsr <= n_mfsr;
	     r_vcr <= n_vcr;
	     r_dr <= n_dr;
	     r_ecr <= n_ecr;
	  end
     end // always_ff

endmodule // ecc_memctl
