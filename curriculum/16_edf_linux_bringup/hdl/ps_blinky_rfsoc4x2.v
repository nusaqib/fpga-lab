`timescale 1ns / 1ps

// RFSoC4x2 top - the board's first clocked PL design in this curriculum.
// Even simpler than BlackBoard's: the UltraScale+ PS keeps its DDR4 and
// MIO entirely on dedicated pins that never surface in the wrapper, so
// the top is just the PS system and the payload.
module ps_blinky_rfsoc4x2 (
    output [3:0] led
);

    wire pl_clk, pl_resetn;

    ps_sys_wrapper u_ps (
        .pl_clk    (pl_clk),
        .pl_resetn (pl_resetn)
    );

    ps_blinky_core u_core (
        .pl_clk    (pl_clk),
        .pl_resetn (pl_resetn),
        .led       (led)
    );

endmodule
