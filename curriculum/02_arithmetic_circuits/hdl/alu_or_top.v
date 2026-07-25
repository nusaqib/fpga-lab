`timescale 1ns / 1ps

// Same as alu_add_top but opcode fixed to OR.
module alu_or_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire [1:0] result;
    wire       cout;

    alu #(.WIDTH(2)) u_alu (
        .a      (sw[1:0]),
        .b      (sw[3:2]),
        .op     (2'b11),
        .result (result),
        .cout   (cout)
    );

    assign led[1:0] = result;
    assign led[2]   = cout;
    assign led[3]   = 1'b0;

endmodule
