`timescale 1ns / 1ps

// The "driver", in hardware: a sequencer that speaks ADT7420 through the
// i2c_master. Two conversations it knows how to have (both straight from
// the datasheet's transaction diagrams):
//
//  1. Identify (once, at power-up):
//     S, 0x4B+W, [0x0B], Sr, 0x4B+R, [id NACK], P     -> id_ok if 0xCB
//  2. Read temperature (every poll tick):
//     S, 0x4B+W, [0x00], Sr, 0x4B+R, [msb ACK], [lsb NACK], P
//     temp13 = {msb, lsb[7:3]}, signed, 1/16 degC per LSB (13-bit mode
//     is the power-on default).
//
// The repeated START (Sr) in the middle is the piece people trip on:
// writing the register pointer and reading its contents must be ONE
// transaction, or another master could sneak in between (and some
// devices reset state on STOP).
module adt7420_reader #(
    parameter CLK_HZ  = 100_000_000,
    parameter POLL_HZ = 2
) (
    input             clk,
    input             rst,

    output reg [12:0] temp = 13'h0,        // signed, 1/16 degC
    output reg        temp_valid = 1'b0,  // pulses per successful read
    output reg        id_ok = 1'b0,       // ADT7420 answered 0xCB at reg 0x0B
    output reg        bus_error = 1'b0,   // an expected ACK never came

    // i2c_master command channel
    output reg        cmd_valid = 1'b0,
    output reg [1:0]  cmd = 2'h0,
    output reg [7:0]  wdata = 8'h0,
    output reg        rd_ack = 1'b0,
    input             busy,
    input      [7:0]  rdata,
    input             ack_error
);

    localparam [1:0] CMD_START = 2'd0,
                     CMD_WRITE = 2'd1,
                     CMD_READ  = 2'd2,
                     CMD_STOP  = 2'd3;

    localparam [7:0] ADDR_W = {7'h4B, 1'b0},
                     ADDR_R = {7'h4B, 1'b1};

    localparam POLL_DIV = CLK_HZ / POLL_HZ;
    reg [$clog2(POLL_DIV)-1:0] poll_cnt = 0;
    wire poll = (poll_cnt == POLL_DIV - 1);
    always @(posedge clk)
        poll_cnt <= (rst || poll) ? 0 : poll_cnt + 1'b1;

    // One linear script, stepped through by an index: each entry issues
    // one i2c_master command and waits for !busy. Two scripts share the
    // steps array shape: identify (steps 0-5) and read temp (steps 6-13).
    reg [3:0] step = 0;
    reg       running = 0;
    reg       identified = 0;
    reg       cmd_sent = 0;
    reg [7:0] msb = 0;

    always @(posedge clk) begin
        temp_valid <= 1'b0;
        if (rst) begin
            step <= 0;
            running <= 0;
            identified <= 0;
            cmd_valid <= 0;
            cmd_sent <= 0;
            id_ok <= 0;
            bus_error <= 0;
            temp <= 0;
        end else begin
            cmd_valid <= 1'b0;

            if (!running) begin
                if (!identified) begin
                    running <= 1'b1;
                    step <= 0;
                end else if (poll) begin
                    running <= 1'b1;
                    step <= 6;
                end
            end else if (!busy && !cmd_valid && !cmd_sent) begin
                cmd_sent <= 1'b1;
                cmd_valid <= 1'b1;
                case (step)
                    // ---- identify ----
                    4'd0: begin cmd <= CMD_START; end
                    4'd1: begin cmd <= CMD_WRITE; wdata <= ADDR_W; end
                    4'd2: begin cmd <= CMD_WRITE; wdata <= 8'h0B; end
                    4'd3: begin cmd <= CMD_START; end
                    4'd4: begin cmd <= CMD_WRITE; wdata <= ADDR_R; end
                    4'd5: begin cmd <= CMD_READ;  rd_ack <= 1'b0; end
                    // ---- read temperature ----
                    4'd6: begin cmd <= CMD_START; end
                    4'd7: begin cmd <= CMD_WRITE; wdata <= ADDR_W; end
                    4'd8: begin cmd <= CMD_WRITE; wdata <= 8'h00; end
                    4'd9: begin cmd <= CMD_START; end
                    4'd10: begin cmd <= CMD_WRITE; wdata <= ADDR_R; end
                    4'd11: begin cmd <= CMD_READ; rd_ack <= 1'b1; end
                    4'd12: begin cmd <= CMD_READ; rd_ack <= 1'b0; end
                    default: begin cmd <= CMD_STOP; end
                endcase
            end else if (cmd_sent && !busy && !cmd_valid) begin
                // command accepted and finished
                cmd_sent <= 1'b0;
                if (ack_error && (step == 4'd1 || step == 4'd2 ||
                                  step == 4'd4 || step == 4'd7 ||
                                  step == 4'd8 || step == 4'd10)) begin
                    bus_error <= 1'b1;    // nobody home: bail to STOP
                    step <= 4'd13;
                end else begin
                    case (step)
                        4'd5: begin
                            id_ok <= (rdata == 8'hCB);
                            identified <= 1'b1;
                            step <= 4'd13;   // STOP next
                        end
                        4'd11: begin
                            msb <= rdata;
                            step <= 4'd12;
                        end
                        4'd12: begin
                            temp <= {msb[7:0], rdata[7:3]};
                            temp_valid <= 1'b1;
                            step <= 4'd13;
                        end
                        4'd13: running <= 1'b0;
                        default: step <= step + 1'b1;
                    endcase
                end
            end
        end
    end

endmodule
