`timescale 1ns / 1ps

// Thin shell: board pins -> the generated BD wrapper. All the substance
// lives in the block design (jtag_axi master -> axil_regs) and in
// axil_regs.v itself. External reset is tied inactive - proc_sys_reset
// inside the BD generates the real synchronized AXI reset.
module axil_demo_top (
    input        clk,
    input        btn,
    input  [3:0] sw,
    output [3:0] led
);

    jtag_axi_sys_wrapper u_bd (
        .clk    (clk),
        .resetn (1'b1),
        .btn    (btn),
        .sw     (sw),
        .led    (led)
    );

endmodule
