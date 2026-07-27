`timescale 1ns / 1ps

// A byte-level I2C master, from scratch - because after writing one, a
// datasheet's I2C timing diagram reads like source code.
//
// I2C in four sentences: both lines are open-drain with pull-ups, so
// anyone can pull low but only the resistor drives high (that's why
// multi-master and clock-stretching work at all). A START is SDA
// falling while SCL is high; a STOP is SDA rising while SCL is high;
// everything else changes SDA only while SCL is low. Bits are sampled
// on SCL high, MSB first, 8 at a time. After every byte the receiver
// gets the 9th clock to pull SDA low ("ACK") - a high there means
// nobody's home.
//
// Command interface (one command at a time, pulse cmd_valid when !busy):
//   CMD_START  - (re)start condition
//   CMD_WRITE  - send wdata, capture ACK in ack_error (1 = no ack)
//   CMD_READ   - clock in a byte to rdata; send ACK if rd_ack else NACK
//   CMD_STOP   - stop condition, releases the bus
//
// SDA is split into sda_i/sda_pull for the top to wire to a real
// open-drain pad (assign sda = sda_pull ? 1'b0 : 1'bz). Same for SCL -
// this master doesn't stretch, but a slave legally could, so SCL is
// checked to have actually risen before a bit counts (stretch-safe).
module i2c_master #(
    parameter CLK_HZ = 100_000_000,
    parameter I2C_HZ = 100_000
) (
    input        clk,
    input        rst,

    input        cmd_valid,
    input  [1:0] cmd,           // see localparams below
    input  [7:0] wdata,
    input        rd_ack,        // for CMD_READ: 1 = ACK (more to come)
    output reg   busy = 1'b0,
    output reg [7:0] rdata = 8'h0,
    output reg   ack_error = 1'b0,     // last CMD_WRITE unacknowledged

    input        scl_i,
    output reg   scl_pull = 1'b0, // 1 = pull SCL low
    input        sda_i,
    output reg   sda_pull = 1'b0  // 1 = pull SDA low
);

    localparam [1:0] CMD_START = 2'd0,
                     CMD_WRITE = 2'd1,
                     CMD_READ  = 2'd2,
                     CMD_STOP  = 2'd3;

    // Quarter-bit tick: each SCL period is 4 phases.
    localparam TICK_DIV = CLK_HZ / (I2C_HZ * 4);
    reg [$clog2(TICK_DIV)-1:0] tick_cnt = 0;
    wire tick = (tick_cnt == TICK_DIV - 1);
    always @(posedge clk)
        tick_cnt <= (rst || tick) ? 0 : tick_cnt + 1'b1;

    localparam [2:0] S_IDLE  = 3'd0,
                     S_START = 3'd1,
                     S_BITS  = 3'd2,
                     S_ACK   = 3'd3,
                     S_STOP  = 3'd4;

    reg [2:0] state = S_IDLE;
    reg [1:0] phase = 0;        // quarter within the current bit
    reg [3:0] bitno = 0;
    reg [7:0] sh = 0;
    reg       reading = 0;
    reg       ack_bit = 0;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            busy <= 1'b0;
            scl_pull <= 1'b0;
            sda_pull <= 1'b0;
            ack_error <= 1'b0;
            phase <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (cmd_valid && !busy) begin
                        busy  <= 1'b1;
                        phase <= 0;
                        case (cmd)
                            CMD_START: state <= S_START;
                            CMD_STOP:  state <= S_STOP;
                            CMD_WRITE: begin
                                sh <= wdata;
                                reading <= 1'b0;
                                ack_error <= 1'b0;
                                bitno <= 0;
                                state <= S_BITS;
                            end
                            CMD_READ: begin
                                reading <= 1'b1;
                                ack_bit <= rd_ack;
                                bitno <= 0;
                                state <= S_BITS;
                            end
                        endcase
                    end
                end

                // START/repeated START: SDA high, SCL high, then SDA low.
                S_START: if (tick) begin
                    phase <= phase + 1'b1;
                    case (phase)
                        2'd0: begin scl_pull <= 1'b1; sda_pull <= 1'b0; end
                        2'd1: scl_pull <= 1'b0;      // SCL released high
                        2'd2: if (scl_i) sda_pull <= 1'b1;   // SDA falls: START
                              else phase <= phase;   // wait out a stretcher
                        2'd3: begin
                            scl_pull <= 1'b1;
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end
                    endcase
                end

                // 8 data bits, then the ACK bit (direction depends on r/w).
                S_BITS: if (tick) begin
                    phase <= phase + 1'b1;
                    case (phase)
                        2'd0: begin                  // SCL low: set SDA
                            scl_pull <= 1'b1;
                            if (bitno == 4'd8)
                                // pulling low IS the ACK (a fresh way to
                                // get this backwards: found by the bench)
                                sda_pull <= reading ? ack_bit : 1'b0;
                            else
                                sda_pull <= reading ? 1'b0 : ~sh[7];
                        end
                        2'd1: scl_pull <= 1'b0;      // release SCL
                        2'd2: begin                  // SCL high: sample
                            if (!scl_i)
                                phase <= phase;      // slave stretching
                            else if (bitno == 4'd8) begin
                                if (!reading)
                                    ack_error <= sda_i;   // 1 = NACK
                            end else if (reading)
                                sh <= {sh[6:0], sda_i};
                        end
                        2'd3: begin
                            scl_pull <= 1'b1;
                            if (bitno == 4'd8) begin
                                if (reading)
                                    rdata <= sh;
                                sda_pull <= 1'b0;
                                busy <= 1'b0;
                                state <= S_IDLE;
                            end else begin
                                if (!reading)
                                    sh <= {sh[6:0], 1'b0};
                                bitno <= bitno + 1'b1;
                            end
                        end
                    endcase
                end

                // STOP: SDA low, SCL high, then SDA high.
                S_STOP: if (tick) begin
                    phase <= phase + 1'b1;
                    case (phase)
                        2'd0: begin scl_pull <= 1'b1; sda_pull <= 1'b1; end
                        2'd1: scl_pull <= 1'b0;
                        2'd2: if (scl_i) sda_pull <= 1'b0;   // SDA rises: STOP
                              else phase <= phase;
                        2'd3: begin
                            busy <= 1'b0;
                            state <= S_IDLE;
                        end
                    endcase
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
