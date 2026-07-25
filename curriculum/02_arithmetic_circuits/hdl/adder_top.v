`timescale 1ns / 1ps

// Hardware demo for ripple_carry_adder: sw[1:0] and sw[3:2] are two 2-bit
// numbers, led[1:0] shows their sum and led[2] shows the carry-out (so
// e.g. sw=4'b1111 -> a=3, b=3 -> led reads carry=1, sum=2 (3+3=6=0b110)).
module adder_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire [1:0] sum;
    wire       cout;

    ripple_carry_adder #(.WIDTH(2)) u_adder (
        .a    (sw[1:0]),
        .b    (sw[3:2]),
        .cin  (1'b0),
        .sum  (sum),
        .cout (cout)
    );

    assign led[1:0] = sum;
    assign led[2]   = cout;
    assign led[3]   = 1'b0;

endmodule
