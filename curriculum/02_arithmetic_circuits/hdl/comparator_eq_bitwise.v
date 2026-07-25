`timescale 1ns / 1ps

// Same equality check as comparator.v's `eq`, built explicitly instead of
// trusting `==`: two numbers are equal exactly when every corresponding
// bit pair matches. A second `generate` example, this time producing an
// array of per-bit results (XNOR - 1 exactly when a[i] and b[i] match) that
// then get combined with a reduction operator (`&bit_eq` ANDs every bit of
// bit_eq together - the whole vector is 1 only if every element is 1).
// sim/tb_comparator_eq_bitwise.v checks this matches comparator.v's `eq`
// for every input.
module comparator_eq_bitwise #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output             eq
);

    wire [WIDTH-1:0] bit_eq;

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bit_compare
            assign bit_eq[i] = ~(a[i] ^ b[i]);
        end
    endgenerate

    assign eq = &bit_eq;

endmodule
