`timescale 1ns / 1ps

// Top for the IBERT bring-up of the RFSoC4x2's QSFP28 GTY quad (quad 128).
//
// Adapted from the IBERT IP's own generated example design
// (example_ibert_qsfp.v) with the unused MGTREFCLK1 path removed: the
// board wires one 156.25 MHz reference (GTY_128_REF_CLK_QSFP, package
// pins AA33/AA34 per the RealDigital reference manual - and Vivado's own
// pin assignment for MGTREFCLK0_128 agrees) into the quad; everything
// else the four lanes need is inside the transceivers.
//
// What the pieces are:
//  - IBUFDS_GTE4: the dedicated refclk input buffer of the GT bank. Its
//    O output feeds the QPLL/channels; ODIV2 is a fabric-usable copy.
//  - BUFG_GT: the only legal way to get that clock onto fabric routing -
//    it drives the IBERT core's internal logic and the debug hub (the
//    "system clock" - configured as QUAD128_0 in the IP, i.e. this).
//  - The IBERT core itself contains the pattern generators, checkers,
//    eye-scan engines and the JTAG plumbing the Hardware Manager talks to.
//
// QSFP sideband: a plugged module must be out of reset and out of
// low-power mode before its lasers/retimers run - driven constant here
// so a passive loopback plug "just works". Internal (PCS/PMA) loopback
// needs no module at all.
module ibert_qsfp_top (
    output [3:0] gty_txn_o,
    output [3:0] gty_txp_o,
    input  [3:0] gty_rxn_i,
    input  [3:0] gty_rxp_i,
    input        gty_refclk0p_i,
    input        gty_refclk0n_i,
    output       qsfp_resetl,     // 1 = module out of reset
    output       qsfp_lpmode      // 0 = full power mode
);

    assign qsfp_resetl = 1'b1;
    assign qsfp_lpmode = 1'b0;

    wire gty_refclk0;
    wire gty_odiv2_0;
    wire gty_sysclk;

    IBUFDS_GTE4 u_buf_q128_clk0 (
        .O     (gty_refclk0),
        .ODIV2 (gty_odiv2_0),
        .CEB   (1'b0),
        .I     (gty_refclk0p_i),
        .IB    (gty_refclk0n_i)
    );

    BUFG_GT u_sysclk (
        .I       (gty_odiv2_0),
        .O       (gty_sysclk),
        .CE      (1'b1),
        .CEMASK  (1'b0),
        .CLR     (1'b0),
        .CLRMASK (1'b0),
        .DIV     (3'b000)
    );

    ibert_qsfp u_ibert_gty_core (
        .txn_o             (gty_txn_o),
        .txp_o             (gty_txp_o),
        .rxn_i             (gty_rxn_i),
        .rxp_i             (gty_rxp_i),
        .clk               (gty_sysclk),
        .gtrefclk0_i       (gty_refclk0),
        .gtrefclk1_i       (1'b0),
        .gtnorthrefclk0_i  (1'b0),
        .gtnorthrefclk1_i  (1'b0),
        .gtsouthrefclk0_i  (1'b0),
        .gtsouthrefclk1_i  (1'b0),
        .gtrefclk00_i      (gty_refclk0),
        .gtrefclk10_i      (1'b0),
        .gtrefclk01_i      (1'b0),
        .gtrefclk11_i      (1'b0),
        .gtnorthrefclk00_i (1'b0),
        .gtnorthrefclk10_i (1'b0),
        .gtnorthrefclk01_i (1'b0),
        .gtnorthrefclk11_i (1'b0),
        .gtsouthrefclk00_i (1'b0),
        .gtsouthrefclk10_i (1'b0),
        .gtsouthrefclk01_i (1'b0),
        .gtsouthrefclk11_i (1'b0)
    );

endmodule
