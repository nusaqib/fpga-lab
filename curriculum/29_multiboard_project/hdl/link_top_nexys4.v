`timescale 1ns / 1ps

// Nexys4 end of the link (ID 0x01). Cable: JA1 -> BlackBoard JB2,
// JA2 <- BlackBoard JB1, plus GND-to-GND (always GND - two boards on
// different supplies have no shared reference until you give them one).
module link_top_nexys4 (
    input         clk100,
    output        ja1_txd,
    input         ja2_rxd,
    output [15:0] led
);

    wire [7:0] peer_id, peer_cnt;
    wire link_up, rx_activity;

    link_node #(.MY_ID(8'h01)) u_node (
        .clk(clk100),
        .txd(ja1_txd), .rxd(ja2_rxd),
        .peer_id(peer_id), .peer_cnt(peer_cnt), .peer_fresh(),
        .link_up(link_up), .rx_activity(rx_activity)
    );

    // the OTHER board's counter on our LEDs - that's the demo
    assign led = {link_up, rx_activity, 6'b0, peer_cnt};

endmodule
