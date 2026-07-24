`timescale 1ns / 1ps

// 4-to-1 multiplexer using an always @* block with a case statement - the
// "procedural" style of combinational logic. Functionally equivalent to a
// nested assign/ternary chain, but this is how most non-trivial
// combinational logic actually gets written.
module mux4to1 (
    input  [3:0] data,
    input  [1:0] sel,
    output reg   y
);

    always @* begin
        case (sel)
            2'd0: y = data[0];
            2'd1: y = data[1];
            2'd2: y = data[2];
            2'd3: y = data[3];
            default: y = 1'bx;
        endcase
    end

endmodule
