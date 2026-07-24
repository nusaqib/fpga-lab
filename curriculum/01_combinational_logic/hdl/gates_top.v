`timescale 1ns / 1ps

// Hardware demo for logic_gates: sw[1:0] are the two inputs, and each LED
// shows a different gate's output of the same two switches - flip sw[0]/
// sw[1] and watch all four truth tables at once.
module gates_top (
    input  [3:0] sw,
    output [3:0] led
);

    logic_gates u_gates (
        .a     (sw[0]),
        .b     (sw[1]),
        .y_and (led[0]),
        .y_or  (led[1]),
        .y_xor (led[2]),
        .y_nand(led[3])
    );

endmodule
