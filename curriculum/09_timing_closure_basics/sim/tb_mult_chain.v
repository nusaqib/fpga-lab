`timescale 1ns / 1ps

// Functional equivalence of the slow and pipelined chains: same input
// stream into both; the pipelined result, delayed by its extra 2 cycles
// of latency, must match the slow result exactly. (Timing differences are
// invisible to behavioral simulation - this bench proves the pipelining
// changed WHEN answers arrive, never WHAT they are. The timing story
// lives in the synthesis reports, not here.)
module tb_mult_chain;

    localparam CYCLES = 500;

    reg         clk = 0;
    reg  [31:0] x;
    wire [31:0] r_slow, r_pipe;
    reg  [31:0] slow_d1, slow_d2;   // slow result delayed 2 to align
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    mult_chain_slow      u_slow (.clk(clk), .x(x), .result(r_slow));
    mult_chain_pipelined u_pipe (.clk(clk), .x(x), .result(r_pipe));

    always @(posedge clk) begin
        slow_d1 <= r_slow;
        slow_d2 <= slow_d1;
    end

    initial begin
        x = 0;
        repeat (6) @(negedge clk);   // flush both pipes with x=0

        for (i = 0; i < CYCLES; i = i + 1) begin
            x = $random;
            @(negedge clk);
            if (i > 6 && r_pipe !== slow_d2) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: pipelined=%h slow(delayed2)=%h", i, r_pipe, slow_d2);
            end
        end

        if (errors == 0) $display("PASS: tb_mult_chain - pipelined matches slow chain (2-cycle offset) over %0d cycles", CYCLES);
        else              $display("FAIL: tb_mult_chain - %0d error(s)", errors);
        $finish;
    end

endmodule
