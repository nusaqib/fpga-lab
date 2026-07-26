`timescale 1ns / 1ps

// The fix for mult_chain_slow: same three multiplies, but with a register
// after each one - the classic pipeline. Each clock cycle now spans ONE
// multiply instead of three, so the critical path is a third the length
// (and each stage register can also be pulled INTO the DSP48 primitive's
// internal pipeline registers, making it faster still).
//
// The price is LATENCY: the answer for a given x appears 4 edges after
// x_r captured it (vs 2 for the slow version), and the module produces
// one result per cycle either way (throughput unchanged - that's the
// pipeline bargain: latency up, clock rate way up, throughput per clock
// identical).
module mult_chain_pipelined (
    input             clk,
    input      [31:0] x,
    output reg [31:0] result = 0
);

    reg [31:0] x_r = 0;
    reg [31:0] s1 = 0, s2 = 0;

    always @(posedge clk) begin
        x_r    <= x;
        s1     <= x_r * 32'h9E3779B1;   // same constants as the slow one -
        s2     <= s1  * 32'h85EBCA77;   // the bench checks equivalence
        result <= s2  * 32'hC2B2AE3D;
    end

endmodule
