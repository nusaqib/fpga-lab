`timescale 1ns / 1ps

// Hardware demo for comparator: sw[1:0] and sw[3:2] are two 2-bit numbers,
// led[0]=eq, led[1]=lt, led[2]=gt - exactly one is lit at a time.
module comparator_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire eq, lt, gt;

    comparator #(.WIDTH(2)) u_cmp (
        .a  (sw[1:0]),
        .b  (sw[3:2]),
        .eq (eq),
        .lt (lt),
        .gt (gt)
    );

    assign led[0] = eq;
    assign led[1] = lt;
    assign led[2] = gt;
    assign led[3] = 1'b0;

endmodule
