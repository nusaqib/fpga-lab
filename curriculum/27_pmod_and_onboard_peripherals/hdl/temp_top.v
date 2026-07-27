`timescale 1ns / 1ps

// Nexys4 top for module 27: the full peripheral stack, no CPU anywhere.
//
//   ADT7420 (real chip on the board, I2C addr 0x4B)
//     -> i2c_master (open-drain pads below)
//     -> adt7420_reader (the transaction "driver")
//     -> this formatter (binary -> "T=+025.5C\r\n")
//     -> uart_tx -> USB-UART -> your terminal at 115200
//
// LEDs mirror the raw 13-bit reading; LED15 = ID check passed,
// LED14 = bus error (latched).
module temp_top (
    input         clk100,
    inout         tmp_scl,
    inout         tmp_sda,
    output        uart_txd,
    output [15:0] led
);

    // --- open-drain pads: pull low or float, never drive high ---
    wire scl_pull, sda_pull;
    assign tmp_scl = scl_pull ? 1'b0 : 1'bz;
    assign tmp_sda = sda_pull ? 1'b0 : 1'bz;

    // (no external reset on this design: power-up init is enough)
    wire rst = 1'b0;

    wire        cmd_valid, rd_ack, busy, ack_error;
    wire [1:0]  cmd;
    wire [7:0]  wdata, rdata;

    i2c_master u_i2c (
        .clk(clk100), .rst(rst),
        .cmd_valid(cmd_valid), .cmd(cmd), .wdata(wdata), .rd_ack(rd_ack),
        .busy(busy), .rdata(rdata), .ack_error(ack_error),
        .scl_i(tmp_scl), .scl_pull(scl_pull),
        .sda_i(tmp_sda), .sda_pull(sda_pull)
    );

    wire [12:0] temp;
    wire        temp_valid, id_ok, bus_error;

    adt7420_reader u_reader (
        .clk(clk100), .rst(rst),
        .temp(temp), .temp_valid(temp_valid),
        .id_ok(id_ok), .bus_error(bus_error),
        .cmd_valid(cmd_valid), .cmd(cmd), .wdata(wdata), .rd_ack(rd_ack),
        .busy(busy), .rdata(rdata), .ack_error(ack_error)
    );

    assign led = {id_ok, bus_error, 1'b0, temp};

    // --- binary -> ASCII line, one temp_valid at a time ---
    // temp is signed 1/16 degC. |temp| fits 12 bits: integer part
    // 0..255, tenths from the fraction (x10/16 = x5/8).
    reg  [12:0] t_lat = 0;
    wire        neg = t_lat[12];
    wire [11:0] mag = neg ? (~t_lat[11:0] + 1'b1) : t_lat[11:0];
    wire [7:0]  int_part = mag[11:4];
    wire [3:0]  tenths   = (mag[3:0] * 4'd10) >> 4;

    // 12-char message: T = + 0 2 5 . 5 C \r \n
    reg [3:0] msg_idx = 0;
    reg       sending = 0;
    reg [7:0] tx_data;
    reg       tx_valid = 0;
    wire      tx_ready;

    wire [7:0] d100 = 8'h30 + int_part / 100;
    wire [7:0] d10  = 8'h30 + (int_part / 10) % 10;
    wire [7:0] d1   = 8'h30 + int_part % 10;

    always @(posedge clk100) begin
        tx_valid <= 1'b0;
        if (temp_valid && !sending) begin
            t_lat <= temp;
            sending <= 1'b1;
            msg_idx <= 0;
        end else if (sending && tx_ready && !tx_valid) begin
            tx_valid <= 1'b1;
            case (msg_idx)
                4'd0: tx_data <= "T";
                4'd1: tx_data <= "=";
                4'd2: tx_data <= neg ? "-" : "+";
                4'd3: tx_data <= d100;
                4'd4: tx_data <= d10;
                4'd5: tx_data <= d1;
                4'd6: tx_data <= ".";
                4'd7: tx_data <= 8'h30 + tenths;
                4'd8: tx_data <= "C";
                4'd9: tx_data <= 8'h0D;
                default: tx_data <= 8'h0A;
            endcase
            if (msg_idx == 4'd10)
                sending <= 1'b0;
            else
                msg_idx <= msg_idx + 1'b1;
        end
    end

    uart_tx u_uart (
        .clk(clk100), .rst(rst),
        .data(tx_data), .valid(tx_valid), .ready(tx_ready),
        .txd(uart_txd)
    );

endmodule
