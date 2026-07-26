`timescale 1ns / 1ps

// The two demos this module earns, in one top:
//
//  - led[3]: THE classic blinky - toggles once per second off a tick_gen.
//    Proof-of-life that the oscillator, constraints, and enable idiom all
//    work. (Bonus tie-in: on BlackBoard, LED0 is literally labeled as the
//    factory design's 1Hz blinker - now it's ours.)
//  - led[2:0]: a 3-bit counter that increments EXACTLY ONCE per button
//    press, via the full raw -> sync2 -> debounce -> edge_detect stack.
//    This is the demo that would visibly break without the debouncer: a
//    single press would jump the count by a random handful.
module blinky_counter_top #(
    // Overridable so the testbench can run with tiny counts instead of
    // simulating a hundred million clocks per blink.
    parameter BLINK_DIV    = 50_000_000,   // toggle every 0.5s -> 1Hz blink
    parameter STABLE_COUNT = 1_000_000     // 10ms debounce at 100MHz
) (
    input        clk,
    input        btn,
    output [3:0] led
);

    // --- blinky ---
    wire blink_tick;
    reg  blink_state = 1'b0;

    tick_gen #(.DIV(BLINK_DIV)) u_tick (
        .clk  (clk),
        .rst  (1'b0),
        .tick (blink_tick)
    );

    always @(posedge clk)
        if (blink_tick) blink_state <= ~blink_state;

    assign led[3] = blink_state;

    // --- press counter ---
    wire btn_clean, btn_pulse;
    reg [2:0] press_count = 3'd0;

    debounce #(.STABLE_COUNT(STABLE_COUNT)) u_db (
        .clk       (clk),
        .rst       (1'b0),
        .noisy_in  (btn),
        .clean_out (btn_clean)
    );

    edge_detect u_edge (
        .clk       (clk),
        .level_in  (btn_clean),
        .pulse_out (btn_pulse)
    );

    always @(posedge clk)
        if (btn_pulse) press_count <= press_count + 1;

    assign led[2:0] = press_count;

endmodule
