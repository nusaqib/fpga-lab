`timescale 1ns / 1ps

// System-level check of the hardware demo: hold the "button", flip the
// "switches", release, keep flipping - the LEDs must track while held
// (allowing the 2-cycle sync2 latency) and freeze after release.
module tb_capture_top;

    reg        clk = 0;
    reg        btn;
    reg  [3:0] sw;
    wire [3:0] led;
    reg  [3:0] frozen;
    integer errors = 0;

    always #5 clk = ~clk;

    capture_top dut (.clk(clk), .btn(btn), .sw(sw), .led(led));

    initial begin
        btn = 0; sw = 4'b0000;
        repeat (4) @(negedge clk);

        // Button held: LEDs follow switches (after sync latency).
        btn = 1; sw = 4'b1010;
        repeat (4) @(negedge clk);   // 2 cycles for sync2 + 1 to capture + margin
        if (led !== 4'b1010) begin errors = errors + 1; $display("FAIL follow-1: led=%b exp=1010", led); end

        sw = 4'b0111;
        repeat (2) @(negedge clk);
        if (led !== 4'b0111) begin errors = errors + 1; $display("FAIL follow-2: led=%b exp=0111", led); end

        // Release: after sync latency drains, LEDs freeze at whatever the
        // switches were at that moment.
        btn = 0;
        repeat (4) @(negedge clk);
        frozen = led;

        sw = 4'b0000;
        repeat (5) @(negedge clk);
        if (led !== frozen) begin errors = errors + 1; $display("FAIL freeze-1: led=%b changed after release (was %b)", led, frozen); end

        sw = 4'b1111;
        repeat (5) @(negedge clk);
        if (led !== frozen) begin errors = errors + 1; $display("FAIL freeze-2: led=%b changed after release (was %b)", led, frozen); end

        if (errors == 0) $display("PASS: tb_capture_top - follows while held, freezes on release");
        else              $display("FAIL: tb_capture_top - %0d error(s)", errors);
        $finish;
    end

endmodule
