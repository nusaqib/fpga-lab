`timescale 1ns / 1ps

// Simulates the real top against the sim stubs (see sim_stubs.v): checks
// that the counter stays in reset until `locked`, then advances every
// derived-clock cycle, and that led[3] mirrors locked.
module tb_ipi_blinky;

    reg  clk = 0;
    wire [3:0] led;
    integer errors = 0;
    integer i;
    reg [25:0] snap1, snap2;

    always #5 clk = ~clk;   // 100MHz

    ipi_blinky_top dut (.clk(clk), .led(led));

    initial begin
        // Before lock: counter must sit at zero.
        repeat (4) @(negedge clk);
        if (dut.counter !== 0) begin
            errors = errors + 1;
            $display("FAIL: counter moving before lock (%0d)", dut.counter);
        end
        if (led[3] !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL: led[3] high before lock");
        end

        // Wait for lock (stub asserts it after 8 slow-clock cycles).
        wait (dut.locked === 1'b1);
        repeat (4) @(negedge clk);
        if (led[3] !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL: led[3] not tracking locked");
        end

        // Counter advances: two snapshots 40 slow-cycles apart must differ
        // by exactly 40.
        @(negedge dut.clk_25m);
        snap1 = dut.counter;
        repeat (40) @(negedge dut.clk_25m);
        snap2 = dut.counter;
        if (snap2 - snap1 !== 26'd40) begin
            errors = errors + 1;
            $display("FAIL: counter advanced %0d in 40 slow cycles", snap2 - snap1);
        end

        if (errors == 0) $display("PASS: tb_ipi_blinky - reset-until-lock + counting in the derived domain");
        else              $display("FAIL: tb_ipi_blinky - %0d error(s)", errors);
        $finish;
    end

endmodule
