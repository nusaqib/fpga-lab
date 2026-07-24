`timescale 1ns / 1ps

// Four basic two-input gates, each a single continuous assignment - the
// "assign" style of combinational logic: describe *what* the output equals,
// not a sequence of steps to compute it.
module logic_gates (
    input  a,
    input  b,
    output y_and,
    output y_or,
    output y_xor,
    output y_nand
);

    assign y_and  = a & b;
    assign y_or   = a | b;
    assign y_xor  = a ^ b;
    assign y_nand = ~(a & b);

endmodule
