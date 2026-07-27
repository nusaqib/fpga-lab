`timescale 1ns / 1ps

// UART receiver, 8N1: the other half of module 27's transmitter, and
// the half that actually has to work for a living. The line is
// asynchronous to our clock, so: two-flop synchronize it (module 03),
// find the start bit's falling edge, wait HALF a bit to land in the
// middle, then sample each bit at full-bit strides. Landing mid-bit is
// what makes the whole scheme tolerate a few percent of clock mismatch
// between the two boards - which is the entire reason two boards with
// independent oscillators can talk over one wire.
module uart_rx #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
) (
    input            clk,
    input            rxd,
    output reg [7:0] data = 0,
    output reg       valid = 0,     // one-cycle pulse per good byte
    output reg       frame_err = 0  // stop bit was low (line noise/junk)
);

    localparam DIV = CLK_HZ / BAUD;

    // async input: synchronize first, everything else uses rxd_s
    reg [1:0] sync = 2'b11;
    always @(posedge clk) sync <= {sync[0], rxd};
    wire rxd_s = sync[1];

    localparam [1:0] S_IDLE = 0, S_START = 1, S_DATA = 2, S_STOP = 3;
    reg [1:0] state = S_IDLE;
    reg [$clog2(DIV)-1:0] cnt = 0;
    reg [2:0] bitno = 0;
    reg [7:0] sh = 0;

    always @(posedge clk) begin
        valid     <= 1'b0;
        frame_err <= 1'b0;
        case (state)
            S_IDLE: if (!rxd_s) begin       // start bit edge
                state <= S_START;
                cnt <= 0;
            end
            S_START: if (cnt == DIV / 2 - 1) begin
                cnt <= 0;
                if (!rxd_s) begin           // still low mid-start: real
                    state <= S_DATA;
                    bitno <= 0;
                end else
                    state <= S_IDLE;        // glitch, ignore
            end else
                cnt <= cnt + 1'b1;
            S_DATA: if (cnt == DIV - 1) begin
                cnt <= 0;
                sh <= {rxd_s, sh[7:1]};     // LSB first
                if (bitno == 3'd7)
                    state <= S_STOP;
                bitno <= bitno + 1'b1;
            end else
                cnt <= cnt + 1'b1;
            S_STOP: if (cnt == DIV - 1) begin
                cnt <= 0;
                state <= S_IDLE;
                if (rxd_s) begin
                    data  <= sh;
                    valid <= 1'b1;
                end else
                    frame_err <= 1'b1;
            end else
                cnt <= cnt + 1'b1;
        endcase
    end

endmodule
