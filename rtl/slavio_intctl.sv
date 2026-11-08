// -----------------------------------------------------------------------------
// slavio_intctl.sv -- the SS-20 SLAVIO interrupt controller (qemu
// slavio_intctl.c; ss10sim sun4m.cc intctl_t is the reference model).  It
// replaces Henry's IP22 INT3 multiplexor in the same slot.
//   0xff1410000 master: +0 pending, +4 mask (disabled), +8 clear mask
//               (enable), +c set mask (disable), +10 interrupt target CPU
//   0xff140n000 CPU n's slave: +0 pending, +4 clear soft, +8 set soft
//
// The device sources are level inputs (`src`, by master pending bit); each
// maps to a SPARC interrupt level (INTBIT_TO_LEVEL).  The target CPU sees
// the levels of the unmasked pending sources unless the whole controller is
// disabled (mask bit 31); its counter (level 14) is masked only by bit 31;
// the soft interrupts (slave bits 31:17 = levels 15:1) are never masked.
// The CPU's interrupt request level `irl` is the highest level requested.
//
// One CPU: only CPU 0's soft interrupts are kept.  Another CPU's slave
// register reads the source levels if it is the target, and drops writes.
// No source maps to level 15 on this board, so the level-15 input (slave
// bit 15) is never set.
//
// Register-slave interface as Henry's devices.  Word w of the line is lanes
// 4w..4w+3, big-endian; each masked word is one register access.
// -----------------------------------------------------------------------------
`include "machine.vh"

module slavio_intctl(clk, reset, sel, is_store, addr, mask, wdata, rdata, src, cpu0_timer, irl);
   input logic clk;
   input logic reset;
   input logic sel;
   input logic is_store;
   input logic [`PA_WIDTH-1:0] addr;
   input logic [15:0] mask;
   input logic [127:0] wdata;
   output logic [127:0] rdata;
   input logic [31:0] src;
   input logic cpu0_timer;
   output logic [3:0] irl;

   localparam MASTER_IRQ_MASK = 32'hf05dff80;
   localparam MASTER_DISABLE = 32'h80000000;

   logic [31:0] r_disabled;
   logic [31:0] n_disabled;
   logic [3:0]  r_target;
   logic [3:0]  n_target;
   logic [14:0] r_soft;           /* CPU 0's slave bits 31:17 */
   logic [14:0] n_soft;

   wire w_master = (addr[23:16] == 8'h41) & (addr[15:5] == 11'd0);
   wire w_slave = (addr[23:16] == 8'h40) & (addr[11:4] == 8'd0);
   wire [3:0] w_cpun = addr[15:12];

   function logic [31:0] be_word(input logic [127:0] d, input integer w);
      logic [31:0] x;
      x = d[32*w +: 32];
      be_word = {x[7:0], x[15:8], x[23:16], x[31:24]};
   endfunction

   /* the SPARC level of each master pending bit (0 = none) */
   function logic [3:0] level(input integer b);
      case(b)
	0: level = 4'd2;
	1: level = 4'd3;
	2: level = 4'd5;
	3: level = 4'd7;
	4: level = 4'd9;
	5: level = 4'd11;
	6: level = 4'd13;
	7: level = 4'd2;
	8: level = 4'd3;
	9: level = 4'd5;
	10: level = 4'd7;
	11: level = 4'd9;
	12: level = 4'd11;
	13: level = 4'd13;
	14: level = 4'd12;
	15: level = 4'd12;
	16: level = 4'd6;
	17: level = 4'd13;
	18: level = 4'd4;
	19: level = 4'd10;
	20: level = 4'd8;
	21: level = 4'd9;
	22: level = 4'd11;
	27: level = 4'd15;
	28: level = 4'd15;
	29: level = 4'd15;
	30: level = 4'd15;
	default: level = 4'd0;
      endcase
   endfunction

   /* the levels a set of pending bits requests, as a level mask */
   function logic [15:0] levels(input logic [31:0] p);
      logic [15:0] m;
      m = 16'd0;
      for(integer b = 0; b < 32; b = b + 1)
	begin
	   if(p[b] & (level(b) != 4'd0))
	     begin
		m[level(b)] = 1'b1;
	     end
	end
      levels = m;
   endfunction

   wire [31:0] w_pending = src & ~r_disabled;
   wire        w_enabled = !r_disabled[31];
   /* CPU 0's slave pending register: the soft interrupts, its counter and,
    * as the target, the levels of all pending sources */
   wire [15:0] w_shown = levels(src);
   wire [31:0] w_slave0 = {r_soft, 17'd0} | {17'd0, cpu0_timer, 14'd0} |
			  ((r_target == 4'd0) ? {16'd0, w_shown} : 32'd0);
   wire [15:0] w_pil = (((r_target == 4'd0) & w_enabled & (w_pending != 32'd0)) ? levels(w_pending) : 16'd0) |
		       ((w_enabled & cpu0_timer) ? 16'h4000 : 16'd0) |
		       {r_soft, 1'b0};

   always_comb
     begin
	irl = 4'd0;
	for(integer l = 1; l < 16; l = l + 1)
	  begin
	     if(w_pil[l])
	       begin
		  irl = 4'(l);
	       end
	  end
     end // always_comb

   logic [31:0] t_v;
   logic [31:0] t_wv;

   always_comb
     begin
	rdata = 128'd0;
	n_disabled = r_disabled;
	n_target = r_target;
	n_soft = r_soft;
	t_v = 32'd0;
	t_wv = 32'd0;
	for(integer w = 0; w < 4; w = w + 1)
	  begin
	     if(sel & mask[4*w] & (w_master | w_slave))
	       begin
		  t_v = 32'd0;
		  t_wv = be_word(wdata, w);
		  if(w_master)
		    begin
		       case({addr[4], w[1:0]})
			 3'd0:
			   begin
			      t_v = src & ~MASTER_DISABLE;
			   end
			 3'd1:
			   begin
			      t_v = r_disabled & MASTER_IRQ_MASK;
			   end
			 3'd2:
			   begin
			      /* clear = enable */
			      if(is_store)
				begin
				   n_disabled = n_disabled & ~(t_wv & MASTER_IRQ_MASK);
				end
			   end
			 3'd3:
			   begin
			      /* set = disable (pending unaffected) */
			      if(is_store)
				begin
				   n_disabled = n_disabled | (t_wv & MASTER_IRQ_MASK);
				end
			   end
			 3'd4:
			   begin
			      t_v = {28'd0, r_target};
			      if(is_store)
				begin
				   n_target = t_wv[3:0];
				end
			   end
			 default:
			   begin
			      t_v = 32'd0;
			   end
		       endcase
		    end
		  else
		    begin
		       case(w[1:0])
			 2'd0:
			   begin
			      t_v = (w_cpun == 4'd0) ? w_slave0 :
				    (r_target == w_cpun) ? {16'd0, w_shown} : 32'd0;
			   end
			 2'd1:
			   begin
			      /* clear pending soft interrupts */
			      if(is_store & (w_cpun == 4'd0))
				begin
				   n_soft = n_soft & ~t_wv[31:17];
				end
			   end
			 2'd2:
			   begin
			      /* set soft interrupts */
			      if(is_store & (w_cpun == 4'd0))
				begin
				   n_soft = n_soft | t_wv[31:17];
				end
			   end
			 default:
			   begin
			      t_v = 32'd0;
			   end
		       endcase
		    end
		  rdata[32*w +: 32] = {t_v[7:0], t_v[15:8], t_v[23:16], t_v[31:24]};
	       end
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     r_disabled <= ~MASTER_IRQ_MASK;
	     r_target <= 4'd0;
	     r_soft <= 15'd0;
	  end
	else
	  begin
	     r_disabled <= n_disabled;
	     r_target <= n_target;
	     r_soft <= n_soft;
	  end
     end // always_ff

endmodule // slavio_intctl
