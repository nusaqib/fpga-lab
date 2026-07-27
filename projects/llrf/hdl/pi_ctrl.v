`timescale 1ns / 1ps

// One axis of the LLRF loop: PI controller with output clamp, integrator
// clamp (the anti-windup), feedback gating, and feedforward. Runs on the
// decimator's strobe - between strobes the drive holds (zero-order hold
// toward the DAC).
//
//   e     = sp - meas
//   p     = (kp * e) >>> 15
//   acc  += (ki * e)            when fb_en && fb_gate  (acc is Q1.15<<15)
//   u     = sat(p + (acc>>>15) + ff, +/-lim)
//
// The integrator accumulates the FULL-precision ki*e product (Q2.30) so
// tiny errors with small ki still integrate instead of rounding to zero -
// the classic "loop never quite reaches setpoint" bug when the
// accumulator is kept in Q1.15.
//
// Implemented as a three-state sequential engine, not single-cycle: the
// subtract -> DSP multiply -> shift -> 3-term add -> clamp chain is ~17
// logic levels and does NOT close at the 307.2 MHz fabric clock in one
// cycle (first build: WNS -1.47 ns, all failing endpoints in here).
// Strobes arriving while a previous one is still in flight are dropped,
// so the supported operating envelope is DECIM >= 2 (strobe spacing >= 4
// cycles); the bring-up default of DECIM = 8 is 256 cycles apart.
//
// `sat_evt` pulses when the output clamp engaged - the regfile makes it
// a sticky status flag an operator can actually see.
module pi_ctrl (
    input                    clk,
    input                    rst,
    input                    run,        // 0 clears the integrator
    input                    fb_en,      // feedback enabled at all
    input                    fb_gate,    // integrate only inside this window
    input signed [15:0]      sp,
    input signed [15:0]      kp,         // Q1.15
    input signed [15:0]      ki,         // Q1.15, per strobe
    input signed [15:0]      ff,         // feedforward drive
    input        [15:0]      lim,        // positive clamp, Q1.15
    input signed [15:0]      meas,
    input                    strobe,     // one decimated sample arrived
    output reg signed [15:0] drive = 16'sd0,
    output reg               sat_evt = 1'b0
);
    reg signed [33:0] acc = 34'sd0;      // Q2.30 + 2 bits headroom

    // engine state and per-strobe pipeline registers
    reg [1:0]         ph = 2'd0;         // 0 idle, 1 multiply, 2 execute
    reg signed [16:0] e_r = 17'sd0;
    reg signed [32:0] p_full = 33'sd0;   // e * kp, registered (DSP)
    reg signed [32:0] i_full = 33'sd0;   // e * ki, registered (DSP)

    wire signed [17:0] p_term = p_full >>> 15;
    wire signed [17:0] i_term = acc[33:15];                // acc >>> 15
    // NB: ff must widen through a SIGNED wire - a {{4{ff[15]}},ff} concat
    // inline would be an unsigned operand and silently turn the whole sum
    // unsigned (negative p_term zero-extends; found by tb_llrf_loop's
    // pulsed phase, where the fill overshoot makes e go negative).
    wire signed [19:0] ff_ext = ff;
    wire signed [19:0] u_pre  = p_term + i_term + ff_ext;  // + feedforward

    wire signed [19:0] lim_p  = {4'b0, lim};
    wire signed [19:0] lim_n  = -{4'b0, lim};

    // integrator clamp at +/-(lim << 15)
    wire signed [33:0] acc_next  = acc + i_full;
    wire signed [33:0] acc_lim_p = {3'b0, lim, 15'b0};
    wire signed [33:0] acc_lim_n = -{3'b0, lim, 15'b0};

    always @(posedge clk) begin
        if (rst || !run) begin
            acc     <= 34'sd0;
            drive   <= 16'sd0;
            sat_evt <= 1'b0;
            ph      <= 2'd0;
        end else begin
            sat_evt <= 1'b0;
            case (ph)
                2'd0: if (strobe) begin
                    e_r <= sp - meas;
                    ph  <= 2'd1;
                end
                2'd1: begin
                    p_full <= e_r * kp;
                    i_full <= e_r * ki;
                    ph     <= 2'd2;
                end
                default: begin                     // execute
                    if (fb_en) begin
                        if (u_pre > lim_p) begin
                            drive   <= lim_p[15:0];
                            sat_evt <= 1'b1;
                        end else if (u_pre < lim_n) begin
                            drive   <= lim_n[15:0];
                            sat_evt <= 1'b1;
                        end else begin
                            drive <= u_pre[15:0];
                        end
                        if (fb_gate) begin
                            if (acc_next > acc_lim_p)      acc <= acc_lim_p;
                            else if (acc_next < acc_lim_n) acc <= acc_lim_n;
                            else                           acc <= acc_next;
                        end
                    end else begin
                        // open loop: feedforward only, still clamped
                        if      (ff_ext > lim_p) drive <= lim_p[15:0];
                        else if (ff_ext < lim_n) drive <= lim_n[15:0];
                        else                     drive <= ff;
                        acc <= 34'sd0;
                    end
                    ph <= 2'd0;
                end
            endcase
        end
    end
endmodule
