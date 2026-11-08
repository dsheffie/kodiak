// -----------------------------------------------------------------------------
// slavio_timer.sv -- the SS-20 SLAVIO counter/timers (qemu slavio_timer.c; the
// reference model is ss10sim's sun4m.cc, which the co-sim checks every read
// against, so this follows it cycle for cycle):
//   0xff1310000 system timer: +0 limit, +4 counter, +8 limit-no-reset,
//               +c status, +10 user-timer mode (the CPU counters' mode bits)
//   0xff130n000 CPU n's counter (n = 0..3): +0 limit, +4 counter, +8 no-reset,
//               +c status
//
// A counter counts 500 ns periods (CYCLES_PER_TICK clocks) in bits [30:9] up
// to its limit, then wraps to 0, sets reached (bit 31) and raises its
// interrupt; limit 0 free-runs with no interrupt.  A read of the counter
// rounds the periods up (qemu's ptimer); a read of the limit clears the
// interrupt.  CPU 0's counter can instead be a 63-bit user timer (mode bit 0)
// the CPU starts and stops through its status register.
//
// Only the system timer and CPU 0's counter run (as on a one-CPU SS-20, where
// qemu's reset starts just those); the counters of CPUs 1-3 keep their limit
// and status but never count.
//
// Each timer keeps the clocks since its count was last 0 as periods r_p and
// clocks into the period r_q.  The state in a cycle is the time of that
// cycle: a write restarts the count "now" (0), and the tick then takes it to
// the next cycle.
//
// Differences from the C++ model (they would show as DEVICE MODEL MISMATCH):
// the no-reset limit write restarts at 0 instead of the count modulo the new
// period when the count is already past it, and is ignored in user-timer mode.
//
// Register-slave interface as Henry's devices.  Word w of the line is lanes
// 4w..4w+3, big-endian; each masked word is one register access, in order.
// -----------------------------------------------------------------------------
`include "machine.vh"

module slavio_timer(clk, reset, sel, is_store, addr, mask, wdata, rdata, sys_irq, cpu0_irq);
   parameter CYCLES_PER_TICK = 50;
   input logic clk;
   input logic reset;
   input logic sel;
   input logic is_store;
   input logic [`PA_WIDTH-1:0] addr;
   input logic [15:0] mask;
   input logic [127:0] wdata;
   output logic [127:0] rdata;
   output logic sys_irq;
   output logic cpu0_irq;

   localparam LIMIT = 2'd0;
   localparam COUNTER = 2'd1;
   localparam NORST = 2'd2;
   localparam STATUS = 2'd3;

   /* the running timers: 0 = system, 1 = CPU 0 */
   logic [53:0] r_p [1:0];
   logic [53:0] n_p [1:0];
   logic [5:0]  r_q [1:0];
   logic [5:0]  n_q [1:0];
   logic [21:0] r_lim [1:0];      /* limit bits [30:9] */
   logic [21:0] n_lim [1:0];
   logic [1:0]  r_lim64;          /* limit is the user timer's (never wraps) */
   logic [1:0]  n_lim64;
   logic [1:0]  r_on;
   logic [1:0]  n_on;
   logic [1:0]  r_run;
   logic [1:0]  n_run;
   logic [1:0]  r_reached;
   logic [1:0]  n_reached;
   logic [1:0]  r_irq;
   logic [1:0]  n_irq;
   /* CPU 0's user timer */
   logic        r_umode;
   logic        n_umode;
   logic [53:0] r_ubase;          /* count bits [62:9] when last started/written */
   logic [53:0] n_ubase;
   logic [22:0] r_ucnt;           /* last count read out, bits [31:9] */
   logic [22:0] n_ucnt;
   logic [30:0] r_uhi;            /* ... bits [62:32] */
   logic [30:0] n_uhi;
   /* CPUs 1-3: limit and status only */
   logic [21:0] r_slim [2:0];
   logic [21:0] n_slim [2:0];
   logic [2:0]  r_srun;
   logic [2:0]  n_srun;

   wire w_sys = (addr[23:16] == 8'h31) & (addr[15:5] == 11'd0);
   wire w_cpu = (addr[23:16] == 8'h30) & (addr[15:14] == 2'd0) & (addr[11:4] == 8'd0);
   wire [1:0] w_cpun = addr[13:12];

   function logic [31:0] be_word(input logic [127:0] d, input integer w);
      logic [31:0] x;
      x = d[32*w +: 32];
      be_word = {x[7:0], x[15:8], x[23:16], x[31:24]};
   endfunction

   /* the periods a count shows: elapsed periods rounded up */
   function logic [53:0] shown(input logic [53:0] p, input logic [5:0] q);
      shown = p + {53'd0, (q != 6'd0)};
   endfunction

   /* periods in one wrap of a counter with limit bits l */
   function logic [21:0] wrap_n(input logic [21:0] l);
      logic [21:0] n;
      n = ((l == 22'd0) ? 22'h3fffff : l) - 22'd1;
      wrap_n = (n == 22'd0) ? 22'd1 : n;
   endfunction

   /* the user timer's 63-bit count (bits [62:9]) */
   wire [53:0] w_ucount = r_on[1] ? (r_ubase + shown(r_p[1], r_q[1])) : r_ubase;

   logic [31:0] t_v;
   logic [31:0] t_wv;
   logic [53:0] t_p;
   logic [5:0]  t_q;
   integer      i;
   integer      t;
   integer      w;

   always_comb
     begin
	rdata = 128'd0;
	for(i = 0; i < 2; i = i + 1)
	  begin
	     n_p[i] = r_p[i];
	     n_q[i] = r_q[i];
	     n_lim[i] = r_lim[i];
	  end
	for(i = 0; i < 3; i = i + 1)
	  begin
	     n_slim[i] = r_slim[i];
	  end
	n_lim64 = r_lim64;
	n_on = r_on;
	n_run = r_run;
	n_reached = r_reached;
	n_irq = r_irq;
	n_umode = r_umode;
	n_ubase = r_ubase;
	n_ucnt = r_ucnt;
	n_uhi = r_uhi;
	n_srun = r_srun;
	t_v = 32'd0;
	t_wv = 32'd0;
	t_p = 54'd0;
	t_q = 6'd0;
	t = 0;

	for(w = 0; w < 4; w = w + 1)
	  begin
	     if(sel & mask[4*w] & (w_sys | w_cpu))
	       begin
		  t_v = 32'd0;
		  t_wv = be_word(wdata, w);
		  if(w_sys & addr[4])
		    begin
		       /* +0x10: the user-timer mode */
		       if(w == 0)
			 begin
			    t_v = {31'd0, r_umode};
			    if(is_store & (t_wv[0] != r_umode))
			      begin
				 n_umode = t_wv[0];
				 if(t_wv[0])
				   begin
				      /* counter -> user timer, count 0 */
				      n_irq[1] = 1'b0;
				      n_on[1] = n_run[1];
				      n_lim64[1] = 1'b1;
				      n_ubase = 54'd0;
				      n_ucnt = 23'd0;
				      n_uhi = 31'd0;
				   end
				 else
				   begin
				      /* user timer -> counter, always counting */
				      n_on[1] = 1'b1;
				   end
				 n_p[1] = 54'd0;
				 n_q[1] = 6'd0;
			      end
			 end
		    end
		  else if(w_cpu & (w_cpun != 2'd0))
		    begin
		       /* CPUs 1-3: never counting */
		       case(w[1:0])
			 LIMIT:
			   begin
			      t_v = {1'b0, n_slim[w_cpun - 2'd1], 9'd0};
			      if(is_store)
				begin
				   n_slim[w_cpun - 2'd1] = t_wv[30:9];
				end
			   end
			 COUNTER:
			   begin
			      t_v = 32'h7ffffc00;
			   end
			 NORST:
			   begin
			      if(is_store)
				begin
				   n_slim[w_cpun - 2'd1] = t_wv[30:9];
				end
			   end
			 STATUS:
			   begin
			      t_v = {31'd0, n_srun[w_cpun - 2'd1]};
			      if(is_store)
				begin
				   n_srun[w_cpun - 2'd1] = t_wv[0];
				end
			   end
		       endcase
		    end
		  else
		    begin
		       /* timer t: the system timer or CPU 0's counter */
		       t = w_sys ? 0 : 1;
		       case(w[1:0])
			 LIMIT:
			   begin
			      if((t == 1) & n_umode)
				begin
				   /* user timer MSW */
				   if(is_store)
				     begin
					n_lim64[1] = 1'b1;
					n_uhi = t_wv[30:0];
					n_reached[1] = 1'b0;
					n_ubase = {n_uhi, n_ucnt};
					n_p[1] = 54'd0;
					n_q[1] = 6'd0;
				     end
				   else
				     begin
					n_ucnt = w_ucount[22:0];
					n_uhi = w_ucount[53:23];
					t_v = {r_reached[1], w_ucount[53:23]};
				     end
				end
			      else
				begin
				   if(is_store)
				     begin
					/* new limit, count back to 0 */
					n_irq[t] = 1'b0;
					n_lim[t] = t_wv[30:9];
					n_lim64[t] = 1'b0;
					n_p[t] = 54'd0;
					n_q[t] = 6'd0;
				     end
				   else
				     begin
					/* the limit; the read clears the interrupt */
					t_v = r_lim64[t] ? 32'h7ffffe00 : {1'b0, r_lim[t], 9'd0};
					n_irq[t] = 1'b0;
					n_reached[t] = 1'b0;
				     end
				end
			   end
			 COUNTER:
			   begin
			      if((t == 1) & n_umode)
				begin
				   /* user timer LSW */
				   if(is_store)
				     begin
					n_lim64[1] = 1'b1;
					n_ucnt = t_wv[31:9];
					n_reached[1] = 1'b0;
					n_ubase = {n_uhi, n_ucnt};
					n_p[1] = 54'd0;
					n_q[1] = 6'd0;
				     end
				   else
				     begin
					n_ucnt = w_ucount[22:0];
					n_uhi = w_ucount[53:23];
					t_v = {w_ucount[22:0], 9'd0};
				     end
				end
			      else if(!is_store)
				begin
				   t_p = shown(r_p[t], r_q[t]);
				   t_v = r_on[t] ? {r_reached[t], t_p[21:0], 9'd0} : {r_reached[t], 31'h7ffffc00};
				end
			   end
			 NORST:
			   begin
			      if(is_store & !((t == 1) & n_umode))
				begin
				   /* new limit, count kept */
				   n_lim[t] = t_wv[30:9];
				   n_lim64[t] = 1'b0;
				   n_q[t] = 6'd0;
				   if(n_p[t] >= {32'd0, wrap_n(t_wv[30:9])})
				     begin
					n_p[t] = 54'd0;
				     end
				end
			   end
			 STATUS:
			   begin
			      t_v = (t == 1) ? {31'd0, r_run[1]} : 32'd0;
			      if(is_store)
				begin
				   if((t == 1) & n_umode)
				     begin
					/* start/stop the user timer */
					if(t_wv[0] & !n_on[1])
					  begin
					     n_on[1] = 1'b1;
					     n_p[1] = 54'd0;
					     n_q[1] = 6'd0;
					  end
					else if(!t_wv[0] & n_on[1])
					  begin
					     n_ubase = w_ucount;
					     n_on[1] = 1'b0;
					  end
				     end
				   n_run[t] = t_wv[0];
				end
			   end
		       endcase
		    end
		  rdata[32*w +: 32] = {t_v[7:0], t_v[15:8], t_v[23:16], t_v[31:24]};
	       end
	  end

	/* the tick: from this cycle's count to the next cycle's */
	for(i = 0; i < 2; i = i + 1)
	  begin
	     if(n_on[i])
	       begin
		  t_p = n_p[i];
		  t_q = n_q[i] + 6'd1;
		  if(t_q == 6'(CYCLES_PER_TICK))
		    begin
		       t_q = 6'd0;
		       t_p = t_p + 54'd1;
		    end
		  if(!n_lim64[i] & !((i == 1) & n_umode) & (t_q == 6'd0) & (t_p == {32'd0, wrap_n(n_lim[i])}))
		    begin
		       t_p = 54'd0;
		       if(n_lim[i] != 22'd0)
			 begin
			    n_reached[i] = 1'b1;
			    n_irq[i] = 1'b1;
			 end
		    end
		  n_p[i] = t_p;
		  n_q[i] = t_q;
	       end
	  end
     end // always_comb

   always_ff @(posedge clk)
     begin
	if(reset)
	  begin
	     /* qemu slavio_timer_reset: the system timer and CPU 0's counter
	      * free-run (limit 0) from the reset */
	     for(i = 0; i < 2; i = i + 1)
	       begin
		  r_p[i] <= 54'd0;
		  r_q[i] <= 6'd0;
		  r_lim[i] <= 22'd0;
	       end
	     for(i = 0; i < 3; i = i + 1)
	       begin
		  r_slim[i] <= 22'd0;
	       end
	     r_lim64 <= 2'b00;
	     r_on <= 2'b11;
	     r_run <= 2'b11;
	     r_reached <= 2'b00;
	     r_irq <= 2'b00;
	     r_umode <= 1'b0;
	     r_ubase <= 54'd0;
	     r_ucnt <= 23'd0;
	     r_uhi <= 31'd0;
	     r_srun <= 3'd0;
	  end
	else
	  begin
	     for(i = 0; i < 2; i = i + 1)
	       begin
		  r_p[i] <= n_p[i];
		  r_q[i] <= n_q[i];
		  r_lim[i] <= n_lim[i];
	       end
	     for(i = 0; i < 3; i = i + 1)
	       begin
		  r_slim[i] <= n_slim[i];
	       end
	     r_lim64 <= n_lim64;
	     r_on <= n_on;
	     r_run <= n_run;
	     r_reached <= n_reached;
	     r_irq <= n_irq;
	     r_umode <= n_umode;
	     r_ubase <= n_ubase;
	     r_ucnt <= n_ucnt;
	     r_uhi <= n_uhi;
	     r_srun <= n_srun;
	  end
     end // always_ff

   assign sys_irq = r_irq[0];
   assign cpu0_irq = r_irq[1];

endmodule // slavio_timer
