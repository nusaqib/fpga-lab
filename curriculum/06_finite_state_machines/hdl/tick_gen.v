`timescale 1ns / 1ps

// Generates a single-cycle `tick` pulse once every DIV clock cycles - the
// clock-ENABLE idiom module 03 promised. Everything downstream still runs
// on the one real clock and just uses `tick` as an enable.
//
// This is deliberately NOT a "clock divider" that produces a new, slower
// clock signal on a flop output (`reg slow_clk; always @(posedge clk)
// slow_clk <= ~slow_clk;` ... `always @(posedge slow_clk)`). That style
// works in simulation and then ages badly in hardware: the derived clock
// arrives via general routing instead of the clock network, timing
// analysis across the two domains gets messy, and every such divider adds
// a new clock domain to reason about. On FPGAs the rule is: one clock,
// many enables (until you genuinely need another clock - then you use a
// clocking primitive/MMCM, which is Tier 4 material).
module tick_gen #(
    parameter DIV = 100_000_000   // default: 1 tick/second at 100MHz
) (
    input  clk,
    input  rst,
    output tick
);

    // Count 0 .. DIV-1, pulse on wrap. $clog2 sizes the counter to fit.
    reg [$clog2(DIV)-1:0] count;

    always @(posedge clk) begin
        if (rst)                  count <= 0;
        else if (count == DIV-1)  count <= 0;
        else                      count <= count + 1;
    end

    assign tick = (count == DIV-1);

endmodule
