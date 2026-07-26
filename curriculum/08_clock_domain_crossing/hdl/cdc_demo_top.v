`timescale 1ns / 1ps

// Hardware demo: module 07's FIFO echo, but the producer now lives in a
// GENUINELY asynchronous clock domain - your thumb. The debounced button
// IS the write clock: each press is one rising edge of wclk, pushing the
// switch pattern into the async FIFO. The read side runs on the 100MHz
// oscillator and pops one entry per second onto the LEDs.
//
// Same UX as fifo_echo_top, completely different machinery underneath:
// the two sides share no clock, and the Gray-coded pointers are what keep
// full/empty truthful across the boundary.
//
// Honesty notes for reading the implemented design later:
//  - Clocking fabric flops from a debounced-button net is fine at human
//    speeds but it IS a fabric-routed clock; Vivado will warn about it
//    and report the write domain as an unconstrained clock. Constraining
//    internal/generated clocks properly is module 09's business.
//  - wr_en is tied high: every wclk edge (= every press) pushes. The
//    debouncer guarantees one clean edge per press - reuse of module 04's
//    lesson in a place where a bounce would mean duplicate FIFO entries.
module cdc_demo_top #(
    parameter POP_DIV      = 100_000_000,  // one pop per second
    parameter STABLE_COUNT = 1_000_000     // 10ms debounce
) (
    input        clk,        // 100MHz - read domain (and debouncer home)
    input        btn,
    input  [3:0] sw,
    output [3:0] led
);

    // The write "clock": one clean rising edge per button press.
    wire btn_clean;
    debounce #(.STABLE_COUNT(STABLE_COUNT)) u_db (
        .clk(clk), .rst(1'b0), .noisy_in(btn), .clean_out(btn_clean)
    );

    wire [3:0] fifo_out;
    wire       empty;
    wire       pop_tick_raw;
    wire       pop_tick = pop_tick_raw && !empty;

    tick_gen #(.DIV(POP_DIV)) u_tick (
        .clk(clk), .rst(1'b0), .tick(pop_tick_raw)
    );

    fifo_async #(.WIDTH(4), .DEPTH(16)) u_fifo (
        .wclk  (btn_clean),
        .wrst  (1'b0),
        .wr_en (1'b1),
        .wdata (sw),
        .full  (),
        .rclk  (clk),
        .rrst  (1'b0),
        .rd_en (pop_tick),
        .rdata (fifo_out),
        .empty (empty)
    );

    reg [3:0] led_r = 4'b0;
    reg       pop_last = 1'b0;
    always @(posedge clk) begin
        pop_last <= pop_tick;
        if (pop_last)
            led_r <= fifo_out;   // FIFO read latency 1
    end

    assign led = led_r;

endmodule
