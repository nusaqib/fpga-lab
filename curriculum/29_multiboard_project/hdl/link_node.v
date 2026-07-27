`timescale 1ns / 1ps

// One end of the two-board link. Identical RTL runs on both boards -
// only the ID parameter and the pins differ. Protocol, all 4 bytes of
// it:
//
//     [0xA5] [my_id] [counter] [sum]      sum = 0xA5+id+counter (mod 256)
//
// sent twice a second. The receiver hunts for 0xA5, collects the next
// three bytes, and accepts the packet only if the checksum closes.
// Framing truth worth stating: 0xA5 can also appear as DATA, so a
// parser can sync onto the middle of a packet - the checksum then
// rejects it and the parser re-hunts, which is why even toy protocols
// need integrity checks, not just magic bytes. (Real links escape or
// encode instead; module 26's 64b/66b discussion is the grown-up form.)
//
// link_up = a valid packet arrived within the last ~1.5s. Unplug the
// cable and watch it drop; replug and it self-heals - no state beyond
// the timeout, which is the whole trick of heartbeat protocols.
module link_node #(
    parameter [7:0] MY_ID = 8'h01,
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200,
    parameter BEAT_HZ = 2
) (
    input        clk,
    output       txd,
    input        rxd,

    output reg [7:0] peer_id  = 0,
    output reg [7:0] peer_cnt = 0,
    output reg       peer_fresh = 0,   // pulse per accepted packet
    output           link_up,
    output           rx_activity
);

    // ---------------- transmit: the heartbeat ----------------
    localparam BEAT_DIV = CLK_HZ / BEAT_HZ;
    reg [$clog2(BEAT_DIV)-1:0] beat_cnt = 0;
    wire beat = (beat_cnt == BEAT_DIV - 1);
    always @(posedge clk)
        beat_cnt <= beat ? 0 : beat_cnt + 1'b1;

    reg [7:0] my_cnt = 0;
    reg [1:0] tx_idx = 0;
    reg       tx_run = 0;
    reg [7:0] tx_data = 0;
    reg       tx_valid = 0;
    wire      tx_ready;

    wire [7:0] my_sum = 8'hA5 + MY_ID + my_cnt;

    always @(posedge clk) begin
        tx_valid <= 1'b0;
        if (beat && !tx_run) begin
            tx_run <= 1'b1;
            tx_idx <= 0;
        end else if (tx_run && tx_ready && !tx_valid) begin
            tx_valid <= 1'b1;
            case (tx_idx)
                2'd0: tx_data <= 8'hA5;
                2'd1: tx_data <= MY_ID;
                2'd2: tx_data <= my_cnt;
                2'd3: tx_data <= my_sum;
            endcase
            if (tx_idx == 2'd3) begin
                tx_run <= 1'b0;
                my_cnt <= my_cnt + 1'b1;
            end
            tx_idx <= tx_idx + 1'b1;
        end
    end

    uart_tx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst(1'b0),
        .data(tx_data), .valid(tx_valid), .ready(tx_ready), .txd(txd)
    );

    // ---------------- receive: hunt, collect, verify ----------------
    wire [7:0] rx_data;
    wire       rx_valid, rx_ferr;

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rxd(rxd),
        .data(rx_data), .valid(rx_valid), .frame_err(rx_ferr)
    );

    reg [1:0] rx_idx = 0;
    reg [7:0] got_id = 0, got_cnt = 0;

    always @(posedge clk) begin
        peer_fresh <= 1'b0;
        if (rx_valid) begin
            case (rx_idx)
                2'd0: if (rx_data == 8'hA5) rx_idx <= 2'd1;
                2'd1: begin got_id  <= rx_data; rx_idx <= 2'd2; end
                2'd2: begin got_cnt <= rx_data; rx_idx <= 2'd3; end
                2'd3: begin
                    rx_idx <= 2'd0;
                    if (rx_data == (8'hA5 + got_id + got_cnt)) begin
                        peer_id    <= got_id;
                        peer_cnt   <= got_cnt;
                        peer_fresh <= 1'b1;
                    end
                    // bad sum: fall back to hunting - mis-sync heals here
                end
            endcase
        end else if (rx_ferr)
            rx_idx <= 2'd0;          // framing junk: re-hunt immediately
    end

    // ---------------- link supervision ----------------
    localparam TIMEOUT = (CLK_HZ / BEAT_HZ) * 3;   // 3 missed beats
    reg [$clog2(TIMEOUT):0] age = TIMEOUT[$clog2(TIMEOUT):0];
    assign link_up = (age != TIMEOUT);

    always @(posedge clk) begin
        if (peer_fresh)
            age <= 0;
        else if (age != TIMEOUT)
            age <= age + 1'b1;
    end

    // a human-visible blink on any received byte
    reg [21:0] act = 0;
    always @(posedge clk)
        if (rx_valid) act <= {22{1'b1}};
        else if (act != 0) act <= act - 1'b1;
    assign rx_activity = act[21];

endmodule
