`timescale 1ns / 1ps

// WIDTH-bit adder built by chaining WIDTH full_adders, each one's carry-out
// feeding the next one's carry-in - `generate`/`genvar` is what lets a
// single full_adder description turn into an arbitrary-width adder without
// hand-copy-pasting it WIDTH times. Naming the generate block
// (`bit_adders`) matters once you start navigating hierarchy in the Vivado
// GUI or writing hierarchical timing constraints later - an unnamed block
// gets an auto-generated name that's much harder to find again.
//
// The obvious drawback this module exists to set up a contrast with:
// carry[i+1] can't be computed until carry[i] is known, so the worst-case
// delay through this adder grows with WIDTH - see cla_adder4.v and the
// module README for the alternative.
module ripple_carry_adder #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input               cin,
    output [WIDTH-1:0] sum,
    output              cout
);

    wire [WIDTH:0] carry;
    assign carry[0] = cin;
    assign cout     = carry[WIDTH];

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : bit_adders
            full_adder u_fa (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

endmodule
