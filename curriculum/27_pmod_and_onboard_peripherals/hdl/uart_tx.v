`timescale 1ns / 1ps

// Minimal UART transmitter, 8N1: idle high, one start bit (low), eight
// data bits LSB first, one stop bit (high). At 115200 baud from 100 MHz
// that's 868 clocks per bit - the design is one counter and one shifter,
// which is exactly why UART never dies.
module uart_tx #(
    parameter CLK_HZ = 100_000_000,
    parameter BAUD   = 115_200
) (
    input        clk,
    input        rst,
    input  [7:0] data,
    input        valid,
    output       ready,
    output reg   txd = 1'b1
);

    localparam DIV = CLK_HZ / BAUD;

    reg [$clog2(DIV)-1:0] baud_cnt = 0;
    reg [3:0] bitno = 0;      // 0 idle, 1 start, 2-9 data, 10 stop
    reg [7:0] sh = 0;

    assign ready = (bitno == 0);

    always @(posedge clk) begin
        if (rst) begin
            bitno <= 0;
            txd <= 1'b1;
            baud_cnt <= 0;
        end else if (bitno == 0) begin
            txd <= 1'b1;
            if (valid) begin
                sh <= data;
                bitno <= 4'd1;
                baud_cnt <= 0;
                txd <= 1'b0;              // start bit begins immediately
            end
        end else if (baud_cnt == DIV - 1) begin
            baud_cnt <= 0;
            bitno <= (bitno == 4'd10) ? 4'd0 : bitno + 1'b1;
            case (bitno)
                4'd1, 4'd2, 4'd3, 4'd4,
                4'd5, 4'd6, 4'd7, 4'd8: begin
                    txd <= sh[0];
                    sh <= {1'b0, sh[7:1]};
                end
                default: txd <= 1'b1;     // stop bit / back to idle
            endcase
        end else
            baud_cnt <= baud_cnt + 1'b1;
    end

endmodule
