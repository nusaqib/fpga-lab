`timescale 1ns / 1ps

// BlackBoard end of the link (ID 0x02), on the always-on 100 MHz PL
// oscillator (H16) - no PS needed, the fabric alone talks to the other
// board. Cable: JB1 -> Nexys4 JA2, JB2 <- Nexys4 JA1, GND to GND.
// Only 4 LEDs here: peer counter LSBs + link_up.
module link_top_blackboard (
    input        CLK100_IN,
    output       jb1_txd,
    input        jb2_rxd,
    output [3:0] led
);

    wire [7:0] peer_id, peer_cnt;
    wire link_up, rx_activity;

    link_node #(.MY_ID(8'h02)) u_node (
        .clk(CLK100_IN),
        .txd(jb1_txd), .rxd(jb2_rxd),
        .peer_id(peer_id), .peer_cnt(peer_cnt), .peer_fresh(),
        .link_up(link_up), .rx_activity(rx_activity)
    );

    assign led = {link_up, peer_cnt[2:0]};

endmodule
