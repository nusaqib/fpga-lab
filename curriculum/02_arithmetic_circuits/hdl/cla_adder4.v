`timescale 1ns / 1ps

// A fixed 4-bit carry-lookahead adder: functionally identical to
// ripple_carry_adder#(.WIDTH(4)) (same sum, same cout, for every input -
// see sim/tb_cla_adder4.v, which checks both against real arithmetic *and*
// against a ripple_carry_adder instance directly), but every carry bit is
// computed straight from a/b instead of waiting on the previous carry.
//
// For each bit i: propagate p[i]=a[i]^b[i] means "if a carry comes in, it
// comes back out"; generate g[i]=a[i]&b[i] means "this bit produces a
// carry on its own, regardless of what comes in." Every carry c[i] can then
// be written as an OR of "some earlier bit generated a carry, and every bit
// between it and here propagated" - which only depends on a/b and cin, not
// on any other carry, so every c[i] can (in principle) be computed in
// parallel instead of one at a time.
//
// Deliberately NOT parameterized/generated like ripple_carry_adder: these
// equations already look unwieldy at just 4 bits (c[3] is a 4-term OR, c[4]
// a 5-term OR) and keep growing per bit - which is itself the point. Real
// wide CLA adders don't extend this by hand; they build a *hierarchy* of
// small lookahead blocks instead (out of scope here, worth remembering as a
// "how do real wide adders actually do this" question for later).
module cla_adder4 (
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    wire [3:0] p, g;
    wire [4:0] c;

    assign p = a ^ b;   // propagate
    assign g = a & b;   // generate

    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1])
                | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);

    assign sum  = p ^ c[3:0];
    assign cout = c[4];

endmodule
