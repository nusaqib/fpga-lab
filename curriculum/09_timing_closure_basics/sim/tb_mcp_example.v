`timescale 1ns / 1ps

// Checks mcp_example's functional contract: result updates only on the
// every-4th-cycle enable, and each update equals the triple-mult of
// whatever x_r held for those 4 cycles.
module tb_mcp_example;

    localparam ROUNDS = 200;

    reg         clk = 0;
    reg  [31:0] x;
    wire [31:0] result;
    reg  [31:0] x_captured, expected;
    reg  [31:0] result_last;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    mcp_example dut (.clk(clk), .x(x), .result(result));

    function [31:0] triple(input [31:0] v);
        triple = ((v * 32'h9E3779B1) * 32'h85EBCA77) * 32'hC2B2AE3D;
    endfunction

    reg [31:0] x_prev;

    initial begin
        x = 32'h1234_5678;
        // sync to the enable: wait until div wraps (watch dut.div)
        @(negedge clk);
        while (dut.div !== 2'b11) @(negedge clk);
        // From here every 4th negedge crosses an enable edge E_i. Note
        // the DUT's contract: at E_i it BOTH captures x_r <= x AND
        // computes result from the OLD x_r - so the result for the value
        // captured at E_i appears at E_{i+1}, one full round later.

        for (i = 0; i < ROUNDS; i = i + 1) begin
            x_captured = x;             // what x_r will capture at E_i
            @(negedge clk);             // crossed E_i: x_r <= x_captured,
                                        // result <= triple(previous capture)
            if (i > 0) begin
                expected = triple(x_prev);
                if (result !== expected) begin
                    errors = errors + 1;
                    $display("FAIL round %0d: result=%h exp=%h", i, result, expected);
                end
            end
            result_last = result;
            x = $random;                // input may wiggle mid-round freely
            @(negedge clk);
            x = $random;
            @(negedge clk);
            if (result !== result_last) begin
                errors = errors + 1;
                $display("FAIL round %0d: result changed between enables", i);
            end
            x = {i[15:0], i[15:0]} ^ 32'hDEAD_BEEF;   // captured at E_{i+1}
            @(negedge clk);             // last cycle of the round
            x_prev = x_captured;
        end

        if (errors == 0) $display("PASS: tb_mcp_example - result updates only on the 4-cycle grid with the right value, %0d rounds", ROUNDS);
        else              $display("FAIL: tb_mcp_example - %0d error(s)", errors);
        $finish;
    end

endmodule
