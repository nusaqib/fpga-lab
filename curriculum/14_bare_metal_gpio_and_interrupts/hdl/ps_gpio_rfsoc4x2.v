`timescale 1ns / 1ps

// RFSoC4x2 top for module 14 - PS system + AXI GPIO, nothing else.
module ps_gpio_rfsoc4x2 (
    input  [3:0] btn,
    output [3:0] led
);

    ps_sys_wrapper u_ps (
        .btn (btn),
        .led (led)
    );

endmodule
