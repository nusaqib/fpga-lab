`timescale 1ns / 1ps

// Hardware demo: sw[1:0] selects which register's output drives the LEDs,
// all advancing on the same ~6Hz tick (fast enough to look alive, slow
// enough to follow by eye):
//
//   sw[1:0] = 00 -> binary up-counter
//   sw[1:0] = 01 -> ring scanner (one hot LED sweeping)
//   sw[1:0] = 10 -> LFSR (pseudo-random pattern, repeats every 15 steps)
//   sw[1:0] = 11 -> shift register eating the LFSR's serial_out-of-sorts:
//                   its input bit is the LFSR's MSB, so you watch bits
//                   marching in one position per tick
module scanner_top #(
    parameter TICK_DIV = 16_000_000   // ~6.25Hz at 100MHz
) (
    input        clk,
    input  [3:0] sw,
    output [3:0] led
);

    wire tick;

    tick_gen #(.DIV(TICK_DIV)) u_tick (
        .clk  (clk),
        .rst  (1'b0),
        .tick (tick)
    );

    wire [3:0] q_count, q_ring, q_lfsr, q_shift;

    counter_updown #(.WIDTH(4)) u_count (
        .clk(clk), .rst(1'b0), .en(tick), .up(1'b1),
        .load(1'b0), .d(4'b0), .count(q_count)
    );

    ring_scanner #(.WIDTH(4)) u_ring (
        .clk(clk), .rst(1'b0), .en(tick), .q(q_ring)
    );

    lfsr4 u_lfsr (
        .clk(clk), .rst(1'b0), .en(tick), .q(q_lfsr)
    );

    shift_register #(.WIDTH(4)) u_shift (
        .clk(clk), .rst(1'b0), .en(tick),
        .serial_in(q_lfsr[3]), .load(1'b0), .d(4'b0),
        .q(q_shift), .serial_out()
    );

    // (Note lfsr4/ring_scanner have no external reset here: both
    // self-seed - lfsr4 can't reach lockup from a nonzero power-up state,
    // and ring_scanner self-corrects - so power-on state is fine for a demo.)

    assign led = (sw[1:0] == 2'b00) ? q_count :
                 (sw[1:0] == 2'b01) ? q_ring  :
                 (sw[1:0] == 2'b10) ? q_lfsr  :
                                      q_shift;

endmodule
