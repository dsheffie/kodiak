// -----------------------------------------------------------------------------
// slavio_misc.sv -- the SS-20 SLAVIO's small system registers (qemu
// slavio_misc.c; ss10sim sun4m.cc is the reference model):
//   0xff1600000 leds    16 bits
//   0xff1800000 aux1     8 bits  (overlays the SLAVIO config reg on an SS-20)
//   0xff1a00000 diag     8 bits
//   0xff1a01000 aux2     8 bits  (power-off / power-fail interrupt clear)
//   0xff1b00000 mdm      8 bits  (modem control)
//   0xff1f00000 sysctrl 32 bits  (system control / reset status)
//
// Register-slave interface as Henry's devices: on `sel` the 16-byte line at
// `addr` (mask = byte enables) is read (combinational `rdata`) and, when
// `is_store`, written (clocked).  Byte k of the line is lane k: wdata/rdata
// [8k+7:8k].  Each register sits big-endian at offset 0 of its line, so an
// 8-bit register is lane 0 and sysctrl's MSB is lane 0.
//
// A sysctrl write of bit 0 requests a system reset (sys_reset_req; the SoC's
// sequencer performs it).  In a system reset (sys_reset) only aux1, aux2 and
// mdm go back to 0: leds, diag and sysctrl (reset status 2) survive, as in
// ss10sim's reset_devices.  Not modeled: the software power-off of aux2 bit 0
// (the testbench's C++ model stops the simulation on it).
// -----------------------------------------------------------------------------
`include "machine.vh"

module slavio_misc(clk, reset, sys_reset, sel, is_store, addr, mask, wdata, rdata, sys_reset_req);
   input logic clk;
   input logic reset;
   input logic sys_reset;
   input logic sel;
   input logic is_store;
   input logic [`PA_WIDTH-1:0] addr;
   input logic [15:0] mask;
   input logic [127:0] wdata;
   output logic [127:0] rdata;
   output logic sys_reset_req;

   logic [15:0] r_leds;
   logic [7:0]  r_aux1;
   logic [7:0]  r_diag;
   logic [7:0]  r_aux2;
   logic [7:0]  r_mdm;
   logic [31:0] r_sysctrl;

   logic [15:0] n_leds;
   logic [7:0]  n_aux1;
   logic [7:0]  n_diag;
   logic [7:0]  n_aux2;
   logic [7:0]  n_mdm;
   logic [31:0] n_sysctrl;

   wire w_line0 = (addr[11:4] == 8'd0);
   wire w_leds = (addr[23:12] == 12'h600) & w_line0;
   wire w_aux1 = (addr[23:12] == 12'h800) & w_line0;
   wire w_diag = (addr[23:12] == 12'ha00) & w_line0;
   wire w_aux2 = (addr[23:12] == 12'ha01) & w_line0;
   wire w_mdm = (addr[23:12] == 12'hb00) & w_line0;
   wire w_sysctrl = (addr[23:12] == 12'hf00) & w_line0;

   wire w_wr = sel & is_store & mask[0];
   wire [7:0] w_b0 = wdata[7:0];
   wire [15:0] w_h0 = {wdata[7:0], wdata[15:8]};
   wire [7:0] w_aux2_wr = {6'd0, w_b0[1:0]} | (r_aux2 & 8'h20);

   always_comb
     begin
	rdata = 128'd0;
	if(w_leds)
	  begin
	     rdata[15:0] = {r_leds[7:0], r_leds[15:8]};
	  end
	else if(w_aux1)
	  begin
	     rdata[7:0] = r_aux1;
	  end
	else if(w_diag)
	  begin
	     rdata[7:0] = r_diag;
	  end
	else if(w_aux2)
	  begin
	     rdata[7:0] = r_aux2;
	  end
	else if(w_mdm)
	  begin
	     rdata[7:0] = r_mdm;
	  end
	else if(w_sysctrl)
	  begin
	     rdata[31:0] = {r_sysctrl[7:0], r_sysctrl[15:8], r_sysctrl[23:16], r_sysctrl[31:24]};
	  end
     end // always_comb

   always_comb
     begin
	n_leds = r_leds;
	n_aux1 = r_aux1;
	n_diag = r_diag;
	n_aux2 = r_aux2;
	n_mdm = r_mdm;
	n_sysctrl = r_sysctrl;
	if(w_wr & w_leds)
	  begin
	     n_leds = w_h0;
	  end
	if(w_wr & w_aux1)
	  begin
	     /* the floppy terminal-count pulse bit never sticks */
	     n_aux1 = w_b0 & 8'hfd;
	  end
	if(w_wr & w_diag)
	  begin
	     n_diag = w_b0;
	  end
	if(w_wr & w_aux2)
	  begin
	     /* writing the power-fail interrupt clear (bit 1) clears it at once */
	     n_aux2 = w_aux2_wr[1] ? (w_aux2_wr & 8'h01) : w_aux2_wr;
	  end
	if(w_wr & w_mdm)
	  begin
	     n_mdm = w_b0;
	  end
	if(w_wr & w_sysctrl & wdata[24])
	  begin
	     /* SYS_RESET: RESETSTAT tells the PROM a system reset happened */
	     n_sysctrl = 32'd2;
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_leds <= 16'd0;
	     r_aux1 <= 8'd0;
	     r_diag <= 8'd0;
	     r_aux2 <= 8'd0;
	     r_mdm <= 8'd0;
	     r_sysctrl <= 32'd0;
	  end
	else if(sys_reset)
	  begin
	     r_aux1 <= 8'd0;
	     r_aux2 <= 8'd0;
	     r_mdm <= 8'd0;
	  end
	else
	  begin
	     r_leds <= n_leds;
	     r_aux1 <= n_aux1;
	     r_diag <= n_diag;
	     r_aux2 <= n_aux2;
	     r_mdm <= n_mdm;
	     r_sysctrl <= n_sysctrl;
	  end
     end // always_ff

   assign sys_reset_req = w_wr & w_sysctrl & wdata[24];

endmodule // slavio_misc
