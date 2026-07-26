`timescale 1ns / 1ps

// DELIBERATELY BAD TIMING - this module exists to fail a 100MHz clock.
// Three chained 32x32 multiplies computed in ONE clock cycle: the
// combinational path from the x register through three DSP cascades to
// the result register is far longer than 10ns. Synthesize it and read the
// negative slack - that's the point. Do not fix this file; the fix lives
// next door in mult_chain_pipelined.v.
module mult_chain_slow (
    input             clk,
    input      [31:0] x,
    output reg [31:0] result = 0
);

    reg [31:0] x_r = 0;

    // one register -> THREE multiplies -> one register: one giant
    // combinational cloud between two flops.
    wire [31:0] p1 = x_r * 32'h9E3779B1;          // arbitrary odd constants
    wire [31:0] p2 = p1  * 32'h85EBCA77;
    wire [31:0] p3 = p2  * 32'hC2B2AE3D;

    always @(posedge clk) begin
        x_r    <= x;
        result <= p3;
    end

endmodule
