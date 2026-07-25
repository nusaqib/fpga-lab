`timescale 1ns / 1ps

// One bit of binary addition - the building block every wider adder in this
// module is made from. sum is the familiar 3-input XOR (odd parity of a,
// b, cin); cout is 1 whenever at least two of the three inputs are 1.
module full_adder (
    input  a,
    input  b,
    input  cin,
    output sum,
    output cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (cin & (a ^ b));

endmodule
