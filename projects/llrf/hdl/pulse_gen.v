`timescale 1ns / 1ps

// The machine timing of the system, in one small module. A cycle counter
// restarts on a trigger (internal period rollover, or a synchronized
// external edge when ext_trig_en) and two programmable windows are cut
// from it:
//
//   trig                 : 1-cycle pulse at t == 0 (arms the capture)
//   rf_gate              : t in [delay,  delay+width)   - drive enabled
//   fb_gate              : t in [fb_dly, fb_dly+fb_wid) - integrator open
//
// CW mode (mode = 0) forces both gates high and keeps emitting trig at
// every period rollover, so periodic diagnostics capture still works on
// a CW system. All comparisons are 32-bit; at 307.2 MHz that allows
// periods up to ~14 s.
module pulse_gen (
    input             clk,
    input             rst,
    input             run,
    input             mode,          // 0 CW, 1 pulsed
    input             ext_trig_en,
    input             ext_trig,      // async input, synchronized here
    input      [31:0] period,
    input      [31:0] delay,
    input      [31:0] width,
    input      [31:0] fb_dly,
    input      [31:0] fb_wid,
    output reg        trig    = 1'b0,
    output reg        rf_gate = 1'b0,
    output reg        fb_gate = 1'b0
);
    // 2FF synchronizer + edge detect for the external trigger
    reg [2:0] ts = 3'b000;
    always @(posedge clk) ts <= {ts[1:0], ext_trig};
    wire ext_rise = ts[1] & ~ts[2];

    reg [31:0] t = 32'd0;
    wire restart = ext_trig_en ? ext_rise : (t >= period - 1);

    always @(posedge clk) begin
        if (rst || !run) begin
            t       <= 32'd0;
            trig    <= 1'b0;
            rf_gate <= 1'b0;
            fb_gate <= 1'b0;
        end else begin
            trig <= restart;               // 1-cycle pulse as t wraps to 0
            if (restart) t <= 32'd0;
            else         t <= t + 32'd1;

            if (!mode) begin               // CW: gates always open
                rf_gate <= 1'b1;
                fb_gate <= 1'b1;
            end else begin
                rf_gate <= (t >= delay)  && (t < delay  + width);
                fb_gate <= (t >= fb_dly) && (t < fb_dly + fb_wid);
            end
        end
    end
endmodule
