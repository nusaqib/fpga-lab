`timescale 1ns / 1ps

// RFSoC4x2 top for module 15.
module ps_regs_rfsoc4x2 (
    input  [3:0] sw,
    input        btn,
    output [3:0] led
);

    ps_sys_wrapper u_ps (
        .sw  (sw),
        .btn (btn),
        .led (led)
    );

endmodule
