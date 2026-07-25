`timescale 1ns / 1ps

// Same as alu_add_top but opcode fixed to SUB. Try sw[1:0]=a=1, sw[3:2]=b=2
// (a<b): led[1:0] reads 3 (1-2 = -1 = 0b11 in 2-bit two's complement) and
// led[2] (carry-out) reads 0 - that 0 is the "borrow occurred" signal.
module alu_sub_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire [1:0] result;
    wire       cout;

    alu #(.WIDTH(2)) u_alu (
        .a      (sw[1:0]),
        .b      (sw[3:2]),
        .op     (2'b01),
        .result (result),
        .cout   (cout)
    );

    assign led[1:0] = result;
    assign led[2]   = cout;
    assign led[3]   = 1'b0;

endmodule
