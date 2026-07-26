`timescale 1ns / 1ps

// Proves pipeline2's output is its input delayed by exactly two clock
// edges: feed a known pseudo-random bit each cycle, keep the last few in a
// small shift-register history, and check q against the bit from two
// cycles ago. If pipeline2's two `<=` statements were blocking `=` in the
// wrong order, this bench would fail with q arriving one cycle early -
// that's the whole non-blocking lesson in executable form.
module tb_pipeline2;

    localparam CYCLES = 200;

    reg  clk = 0;
    reg  d;
    wire q;
    reg  hist1, hist2;   // d one and two edges ago
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    pipeline2 dut (.clk(clk), .d(d), .q(q));

    initial begin
        d = 0; hist1 = 0; hist2 = 0;
        @(negedge clk);

        for (i = 0; i < CYCLES; i = i + 1) begin
            d = $random;
            @(negedge clk);          // one posedge has now passed
            hist2 = hist1;           // shift the history the same way
            hist1 = d;
            if (i >= 2 && q !== hist2) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: q=%b expected d from 2 cycles ago=%b", i, q, hist2);
            end
        end

        if (errors == 0) $display("PASS: tb_pipeline2 - output is input delayed by exactly 2 cycles over %0d cycles", CYCLES);
        else              $display("FAIL: tb_pipeline2 - %0d error(s)", errors);
        $finish;
    end

endmodule
