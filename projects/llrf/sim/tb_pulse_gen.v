`timescale 1ns / 1ps

// Cycle-exact checks of the pulse/timing generator: window edges,
// CW mode, external-trigger mode.
module tb_pulse_gen;

    reg clk = 0;
    always #1.628 clk = ~clk;
    reg rst = 1;

    reg        run = 0, mode = 0, ext_en = 0, ext = 0;
    reg [31:0] period = 100, dly = 10, wid = 20, fdly = 15, fwid = 5;
    wire trig, rf_gate, fb_gate;

    pulse_gen dut (.clk(clk), .rst(rst), .run(run), .mode(mode),
        .ext_trig_en(ext_en), .ext_trig(ext),
        .period(period), .delay(dly), .width(wid),
        .fb_dly(fdly), .fb_wid(fwid),
        .trig(trig), .rf_gate(rf_gate), .fb_gate(fb_gate));

    integer errors = 0;
    integer rf_cycles = 0, fb_cycles = 0, trigs = 0;

    always @(posedge clk) begin
        if (rf_gate) rf_cycles = rf_cycles + 1;
        if (fb_gate) fb_cycles = fb_cycles + 1;
        if (trig)    trigs     = trigs + 1;
    end

    task chk(input [127:0] name, input integer got, input integer exp_v);
        if (got !== exp_v) begin
            $display("FAIL: %0s got %0d expected %0d", name, got, exp_v);
            errors = errors + 1;
        end else
            $display("  ok: %0s = %0d", name, got);
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 0;

        // ---- pulsed, internal trigger: 3 full periods ----
        @(negedge clk);
        mode = 1; run = 1;
        rf_cycles = 0; fb_cycles = 0; trigs = 0;
        // consume the partial first period, then measure 3 clean ones
        repeat (100) @(posedge clk);
        rf_cycles = 0; fb_cycles = 0; trigs = 0;
        repeat (300) @(posedge clk);
        chk("rf cycles /3 periods", rf_cycles, 3 * 20);
        chk("fb cycles /3 periods", fb_cycles, 3 * 5);
        chk("trigs     /3 periods", trigs, 3);

        // ---- CW: gates pinned high ----
        @(negedge clk) mode = 0;
        repeat (5) @(posedge clk);
        rf_cycles = 0; fb_cycles = 0;
        repeat (50) @(posedge clk);
        chk("CW rf cycles", rf_cycles, 50);
        chk("CW fb cycles", fb_cycles, 50);

        // ---- external trigger: exactly one window per edge ----
        @(negedge clk);
        mode = 1; ext_en = 1;
        repeat (250) @(posedge clk);   // no edges -> no windows
        rf_cycles = 0; trigs = 0;
        repeat (50) @(posedge clk);
        chk("ext idle rf", rf_cycles, 0);
        @(negedge clk) ext = 1;
        repeat (5) @(posedge clk);
        @(negedge clk) ext = 0;
        repeat (200) @(posedge clk);
        chk("ext one window rf", rf_cycles, 20);
        chk("ext one trig", trigs, 1);

        // ---- run=0 kills everything ----
        @(negedge clk) run = 0;
        repeat (5) @(posedge clk);
        if (rf_gate || fb_gate) begin
            $display("FAIL: gates high with run=0");
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS: tb_pulse_gen (all checks)");
        else             $display("FAIL: tb_pulse_gen (%0d errors)", errors);
        $finish;
    end
endmodule
