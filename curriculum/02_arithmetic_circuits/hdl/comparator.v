`timescale 1ns / 1ps

// Straightforward behavioral magnitude comparator - let the synthesis tool
// figure out the gates for `==`, `<`, `>`. Contrast with
// comparator_eq_bitwise.v, which builds the equality check up from
// individual bit comparisons by hand instead of trusting the operator.
module comparator #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output             eq,
    output             lt,
    output             gt
);

    assign eq = (a == b);
    assign lt = (a < b);
    assign gt = (a > b);

endmodule
