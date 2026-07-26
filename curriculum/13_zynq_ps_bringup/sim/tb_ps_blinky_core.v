`timescale 1ns / 1ps

// The PL payload, simulated directly (the PS itself has no behavioral
// model worth simulating at this level - on real bring-up you trust the
// silicon and verify YOUR logic's contract with it: hold in reset until
// released, then count).
module tb_ps_blinky_core;

    reg  pl_clk = 0, pl_resetn;
    wire [3:0] led;
    integer errors = 0;
    reg [26:0] snap;

    always #5 pl_clk = ~pl_clk;

    ps_blinky_core dut (.pl_clk(pl_clk), .pl_resetn(pl_resetn), .led(led));

    initial begin
        pl_resetn = 0;
        repeat (10) @(negedge pl_clk);
        if (dut.counter !== 0) begin
            errors = errors + 1;
            $display("FAIL: counter moving while pl_resetn low");
        end
        pl_resetn = 1;
        @(negedge pl_clk);
        snap = dut.counter;
        repeat (100) @(negedge pl_clk);
        if (dut.counter - snap !== 27'd100) begin
            errors = errors + 1;
            $display("FAIL: counter advanced %0d in 100 cycles", dut.counter - snap);
        end

        if (errors == 0) $display("PASS: tb_ps_blinky_core - held in reset, then counts");
        else              $display("FAIL: tb_ps_blinky_core - %0d error(s)", errors);
        $finish;
    end

endmodule
