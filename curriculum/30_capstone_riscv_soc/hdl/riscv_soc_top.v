`timescale 1ns / 1ps

// Nexys4 top for the RISC-V SoC. Nothing but plumbing - the entire
// computer lives in the block design; compare module 00's top, which
// was also "nothing but plumbing" around assign led = sw. The distance
// between those two files is the whole curriculum.
module riscv_soc_top (
    input         clk100,
    input         cpu_resetn,
    input  [15:0] sw,
    output [15:0] led,
    input         uart_rxd,
    output        uart_txd
);

    riscv_soc_wrapper u_soc (
        .clk100     (clk100),
        .cpu_resetn (cpu_resetn),
        .sw         (sw),
        .led        (led),
        .uart_rxd   (uart_rxd),
        .uart_txd   (uart_txd)
    );

endmodule
