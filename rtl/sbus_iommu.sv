// -----------------------------------------------------------------------------
// sbus_iommu.sv -- the SS-20 IOMMU's registers at 0xfe0000000 (qemu
// sun4m_iommu.c; ss10sim sun4m.cc is the reference model):
//   0x0000 CTRL      version 0x13000000 | the written bits 0x1d
//   0x0004 BASE      page-table base, bits 0x07fffc00
//   0x0014 TLBFLUSH  plain (the write is the flush; nothing to flush here)
//   0x0018 PGFLUSH   plain
//   0x1000 AFSR      (v & 0xff0fffff) | 0x00800000
//   0x1004 AFAR      plain
//   0x1008 AER       (v & 0x801f000f) | 1, reset 3
//   0x1010-0x101c    SBus slot n config, bits 0x00010003
//   0x2000 ARBEN     (v & 0x001f0000) | MID 8
//   0x3018 MASK_ID   reset 0x23000000; a write ORs in its low 24 bits
//
// Only the registers: DVMA translation is done on the ARM (the ss10sim C++
// model's iommu_dma), which reads CTRL and BASE through the ctrl/base ports.  qemu and the C++ model keep the whole 16 KB as plain
// storage; the other words here read 0, which the co-sim device compare
// reports as a DEVICE MODEL MISMATCH if software ever reads one back.
//
// Register-slave interface as Henry's devices.  Word w of the line is lanes
// 4w..4w+3, big-endian; each masked word is one register access.
// -----------------------------------------------------------------------------
`include "machine.vh"

module sbus_iommu(clk, reset, sel, is_store, addr, mask, wdata, rdata, ctrl, base);
   input logic clk;
   input logic reset;
   input logic sel;
   input logic is_store;
   input logic [`PA_WIDTH-1:0] addr;
   input logic [15:0] mask;
   input logic [127:0] wdata;
   output logic [127:0] rdata;
   output logic [31:0] ctrl;   /* for the DVMA translation on the ARM */
   output logic [31:0] base;

   localparam IOMMU_VERSION = 32'h13000000;
   localparam IOMMU_AFSR_RESV = 32'h00800000;
   localparam IOMMU_MID = 32'h00000008;

   localparam R_CTRL = 12'h000;
   localparam R_BASE = 12'h001;
   localparam R_TLBFLUSH = 12'h005;
   localparam R_PGFLUSH = 12'h006;
   localparam R_AFSR = 12'h400;
   localparam R_AFAR = 12'h401;
   localparam R_AER = 12'h402;
   localparam R_ARBEN = 12'h800;
   localparam R_MASK_ID = 12'hc06;

   logic [31:0] r_ctrl;
   logic [31:0] r_base;
   logic [31:0] r_tlbflush;
   logic [31:0] r_pgflush;
   logic [31:0] r_afsr;
   logic [31:0] r_afar;
   logic [31:0] r_aer;
   logic [31:0] r_sbcfg[3:0];
   logic [31:0] r_arben;
   logic [31:0] r_mask_id;

   logic [31:0] n_ctrl;
   logic [31:0] n_base;
   logic [31:0] n_tlbflush;
   logic [31:0] n_pgflush;
   logic [31:0] n_afsr;
   logic [31:0] n_afar;
   logic [31:0] n_aer;
   logic [31:0] n_sbcfg[3:0];
   logic [31:0] n_arben;
   logic [31:0] n_mask_id;

   logic [11:0] t_r;
   logic	t_sbcfg;
   logic [31:0] t_v;
   logic [31:0] t_wv;
   integer	w;
   integer	i;

   function logic [31:0] be_word(input logic [127:0] d, input integer w);
      logic [31:0] x;
      x = d[32*w +: 32];
      be_word = {x[7:0], x[15:8], x[23:16], x[31:24]};
   endfunction

   always_comb
     begin
	rdata = 128'd0;
	n_ctrl = r_ctrl;
	n_base = r_base;
	n_tlbflush = r_tlbflush;
	n_pgflush = r_pgflush;
	n_afsr = r_afsr;
	n_afar = r_afar;
	n_aer = r_aer;
	for(i = 0; i < 4; i = i + 1)
	  begin
	     n_sbcfg[i] = r_sbcfg[i];
	  end
	n_arben = r_arben;
	n_mask_id = r_mask_id;
	t_r = 12'd0;
	t_sbcfg = 1'b0;
	t_v = 32'd0;
	t_wv = 32'd0;
	for(w = 0; w < 4; w = w + 1)
	  begin
	     t_r = {addr[13:4], 2'(w)};
	     t_sbcfg = (t_r[11:2] == 10'h101);
	     t_wv = be_word(wdata, w);
	     t_v = (t_r == R_CTRL) ? r_ctrl :
		   (t_r == R_BASE) ? r_base :
		   (t_r == R_TLBFLUSH) ? r_tlbflush :
		   (t_r == R_PGFLUSH) ? r_pgflush :
		   (t_r == R_AFSR) ? r_afsr :
		   (t_r == R_AFAR) ? r_afar :
		   (t_r == R_AER) ? r_aer :
		   t_sbcfg ? r_sbcfg[t_r[1:0]] :
		   (t_r == R_ARBEN) ? r_arben :
		   (t_r == R_MASK_ID) ? r_mask_id :
		   32'd0;
	     if(sel & mask[4*w])
	       begin
		  rdata[32*w +: 32] = {t_v[7:0], t_v[15:8], t_v[23:16], t_v[31:24]};
		  if(is_store)
		    begin
		       if(t_r == R_CTRL)
			 begin
			    n_ctrl = (t_wv & 32'h0000001d) | IOMMU_VERSION;
			 end
		       else if(t_r == R_BASE)
			 begin
			    n_base = t_wv & 32'h07fffc00;
			 end
		       else if(t_r == R_TLBFLUSH)
			 begin
			    n_tlbflush = t_wv;
			 end
		       else if(t_r == R_PGFLUSH)
			 begin
			    n_pgflush = t_wv;
			 end
		       else if(t_r == R_AFSR)
			 begin
			    n_afsr = (t_wv & 32'hff0fffff) | IOMMU_AFSR_RESV;
			 end
		       else if(t_r == R_AFAR)
			 begin
			    n_afar = t_wv;
			 end
		       else if(t_r == R_AER)
			 begin
			    n_aer = (t_wv & 32'h801f000f) | 32'h1;
			 end
		       else if(t_sbcfg)
			 begin
			    n_sbcfg[t_r[1:0]] = t_wv & 32'h00010003;
			 end
		       else if(t_r == R_ARBEN)
			 begin
			    n_arben = (t_wv & 32'h001f0000) | IOMMU_MID;
			 end
		       else if(t_r == R_MASK_ID)
			 begin
			    n_mask_id = r_mask_id | (t_wv & 32'h00ffffff);
			 end
		    end
	       end
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_ctrl <= IOMMU_VERSION;
	     r_base <= 32'd0;
	     r_tlbflush <= 32'd0;
	     r_pgflush <= 32'd0;
	     r_afsr <= IOMMU_AFSR_RESV;
	     r_afar <= 32'd0;
	     r_aer <= 32'd3;
	     for(i = 0; i < 4; i = i + 1)
	       begin
		  r_sbcfg[i] <= 32'd0;
	       end
	     r_arben <= IOMMU_MID;
	     r_mask_id <= 32'h23000000;
	  end
	else
	  begin
	     r_ctrl <= n_ctrl;
	     r_base <= n_base;
	     r_tlbflush <= n_tlbflush;
	     r_pgflush <= n_pgflush;
	     r_afsr <= n_afsr;
	     r_afar <= n_afar;
	     r_aer <= n_aer;
	     for(i = 0; i < 4; i = i + 1)
	       begin
		  r_sbcfg[i] <= n_sbcfg[i];
	       end
	     r_arben <= n_arben;
	     r_mask_id <= n_mask_id;
	  end
     end // always_ff

   assign ctrl = r_ctrl;
   assign base = r_base;

endmodule // sbus_iommu
