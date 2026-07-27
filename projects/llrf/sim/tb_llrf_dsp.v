`timescale 1ns / 1ps

// Unit checks for the LLRF DSP blocks: known vectors through
// iq_beat_mean, dec_pow2, iq_rotate, pi_ctrl. Self-checking; prints
// PASS/FAIL per the repo's sim convention.
module tb_llrf_dsp;

    reg clk = 0;
    always #1.628 clk = ~clk;          // ~307.2 MHz
    reg rst = 1;

    integer errors = 0;

    task check(input [127:0] name, input signed [31:0] got,
               input signed [31:0] exp, input [31:0] tol);
        if ((got > exp + $signed(tol)) || (got < exp - $signed(tol))) begin
            $display("FAIL: %0s got %0d expected %0d (+/-%0d)",
                     name, got, exp, tol);
            errors = errors + 1;
        end else begin
            $display("  ok: %0s = %0d (expected %0d)", name, got, exp);
        end
    endtask

    // ---------------- iq_beat_mean ----------------
    reg  [255:0] beat = 0;
    reg          beat_v = 0;
    wire signed [15:0] mean_i, mean_q;
    wire mean_v;
    iq_beat_mean u_mean (.clk(clk), .rst(rst), .beat(beat),
        .beat_valid(beat_v), .mean_i(mean_i), .mean_q(mean_q),
        .mean_valid(mean_v));

    // ---------------- dec_pow2 ----------------
    reg signed [15:0] d_i = 0, d_q = 0;
    reg d_v = 0;
    wire signed [15:0] dec_i, dec_q;
    wire dec_v;
    dec_pow2 u_dec (.clk(clk), .rst(rst), .n(4'd2),
        .in_i(d_i), .in_q(d_q), .in_valid(d_v),
        .out_i(dec_i), .out_q(dec_q), .out_valid(dec_v));

    // ---------------- iq_rotate ----------------
    reg signed [15:0] r_i = 0, r_q = 0, r_c = 0, r_s = 0;
    reg r_v = 0;
    wire signed [15:0] rot_i, rot_q;
    wire rot_v;
    iq_rotate u_rot (.clk(clk), .rst(rst), .c(r_c), .s(r_s),
        .in_i(r_i), .in_q(r_q), .in_valid(r_v),
        .out_i(rot_i), .out_q(rot_q), .out_valid(rot_v));

    // ---------------- pi_ctrl ----------------
    reg               p_run = 0, p_fb_en = 0, p_gate = 0, p_str = 0;
    reg signed [15:0] p_sp = 0, p_kp = 0, p_ki = 0, p_ff = 0, p_meas = 0;
    reg        [15:0] p_lim = 16'd32767;
    wire signed [15:0] p_drv;
    wire p_sat;
    pi_ctrl u_pi (.clk(clk), .rst(rst), .run(p_run), .fb_en(p_fb_en),
        .fb_gate(p_gate), .sp(p_sp), .kp(p_kp), .ki(p_ki), .ff(p_ff),
        .lim(p_lim), .meas(p_meas), .strobe(p_str),
        .drive(p_drv), .sat_evt(p_sat));

    integer k;
    integer got_dec = 0;
    integer sat_seen = 0;

    always @(posedge clk) if (p_sat) sat_seen = sat_seen + 1;

    initial begin
        repeat (5) @(posedge clk);
        rst = 0;
        repeat (2) @(posedge clk);

        // ---- beat mean: I lanes k*100 (mean 350), Q lanes -k*100 ----
        for (k = 0; k < 8; k = k + 1) begin
            beat[16*k     +: 16] = k * 100;
            beat[128+16*k +: 16] = -k * 100;
        end
        @(negedge clk) beat_v = 1;
        @(negedge clk) beat_v = 0;
        @(posedge clk); @(posedge clk);
        check("mean_i", mean_i, 350, 0);
        check("mean_q", mean_q, -350, 0);

        // ---- dec_pow2 n=2: mean of 10,20,30,40 = 25 ----
        got_dec = 0;
        for (k = 1; k <= 4; k = k + 1) begin
            @(negedge clk);
            d_i = k * 10; d_q = -k * 10; d_v = 1;
        end
        @(negedge clk) d_v = 0;
        repeat (3) @(posedge clk);
        check("dec_i", dec_i, 25, 0);
        check("dec_q", dec_q, -25, 0);

        // ---- rotate (16384, 0) by ~90deg -> (~0, ~16384) ----
        @(negedge clk);
        r_c = 0; r_s = 32767; r_i = 16384; r_q = 0; r_v = 1;
        @(negedge clk) r_v = 0;
        repeat (4) @(posedge clk);
        check("rot_i", rot_i, 0, 2);
        check("rot_q", rot_q, 16384, 2);

        // ---- PI proportional: e=1000, kp=0.5 -> drive 500 ----
        @(negedge clk);
        p_run = 1; p_fb_en = 1; p_gate = 1;
        p_sp = 1000; p_meas = 0; p_kp = 16384; p_ki = 0;
        @(negedge clk) p_str = 1;
        @(negedge clk) p_str = 0;
        repeat (2) @(posedge clk);
        check("pi P-only", p_drv, 500, 1);

        // ---- PI integral: ki=0.1, ten strobes -> +100/strobe on top ----
        @(negedge clk) p_ki = 3277;
        for (k = 0; k < 10; k = k + 1) begin
            @(negedge clk) p_str = 1;
            @(negedge clk) p_str = 0;
        end
        repeat (2) @(posedge clk);
        // drive on the 10th strobe sees the accumulator from the first 9
        // integrations (u is computed before acc updates): 500 + 9*100
        check("pi P+I", p_drv, 1400, 20);

        // ---- clamp + sat flag: lim=600 rails the drive ----
        @(negedge clk) p_lim = 16'd600;
        sat_seen = 0;
        for (k = 0; k < 5; k = k + 1) begin
            @(negedge clk) p_str = 1;
            @(negedge clk) p_str = 0;
        end
        repeat (2) @(posedge clk);
        check("pi clamp", p_drv, 600, 0);
        if (sat_seen == 0) begin
            $display("FAIL: saturation never flagged");
            errors = errors + 1;
        end else
            $display("  ok: sat_evt seen %0d times", sat_seen);

        // ---- run=0 clears the integrator ----
        @(negedge clk) p_run = 0;
        @(negedge clk) p_run = 1; p_lim = 16'd32767; p_ki = 0;
        @(negedge clk) p_str = 1;
        @(negedge clk) p_str = 0;
        repeat (2) @(posedge clk);
        check("pi after clear", p_drv, 500, 1);

        if (errors == 0) $display("PASS: tb_llrf_dsp (all checks)");
        else             $display("FAIL: tb_llrf_dsp (%0d errors)", errors);
        $finish;
    end
endmodule
