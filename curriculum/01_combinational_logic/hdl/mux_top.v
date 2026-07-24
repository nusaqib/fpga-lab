`timescale 1ns / 1ps

// Hardware demo for mux4to1: sw[1:0] selects which bit of a fixed 4-bit
// pattern reaches the output. The data side is a constant here rather than
// switch-driven - no board in this repo has a free-running clock available
// yet for anything more dynamic (see curriculum/README.md's board
// applicability table), and a constant is enough to see led[2] follow
// MUX_DATA[sw[1:0]] as you flip the two select switches.
module mux_top (
    input  [3:0] sw,
    output [3:0] led
);

    localparam [3:0] MUX_DATA = 4'b1101;

    wire mux_out;

    mux4to1 u_mux (
        .data (MUX_DATA),
        .sel  (sw[1:0]),
        .y    (mux_out)
    );

    assign led[1:0] = sw[1:0];  // the select value, for reference...
    assign led[2]   = mux_out;  // ...next to the resulting output
    assign led[3]   = 1'b0;

endmodule
