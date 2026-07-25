`timescale 1ns / 1ps

// Hardware demo for alu, opcode fixed to ADD (only 4 switches exist to
// wire up, no room left for an opcode select alongside two 2-bit operands -
// see alu_sub_top/alu_and_top/alu_or_top for the other three fixed-opcode
// demos). sw[1:0]/sw[3:2] are the two operands; led[1:0]=result,
// led[2]=carry-out.
module alu_add_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire [1:0] result;
    wire       cout;

    alu #(.WIDTH(2)) u_alu (
        .a      (sw[1:0]),
        .b      (sw[3:2]),
        .op     (2'b00),
        .result (result),
        .cout   (cout)
    );

    assign led[1:0] = result;
    assign led[2]   = cout;
    assign led[3]   = 1'b0;

endmodule
