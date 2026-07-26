`timescale 1ns / 1ps

// Pulse synchronizer (toggle method). Problem: a single-cycle pulse in a
// fast domain can fall entirely between two edges of a slow domain's clock
// - run it through sync2 and the slow side may simply never see it. Fix:
// convert the EVENT into a LEVEL CHANGE. Each source pulse flips a toggle
// flop; the toggle level crosses through a two-flop synchronizer (levels
// cross domains safely - they hold still long enough); the destination
// re-derives one pulse per level change with an any-edge detector.
//
// Constraint inherited by the caller: source pulses must be far enough
// apart for each toggle to propagate (roughly 3+ destination clock cycles)
// - fire faster and events MERGE (an even number of pending toggles looks
// like nothing happened). The testbench respects this; an async FIFO (see
// fifo_async.v) is the answer when you can't.
module pulse_sync (
    input  src_clk,
    input  src_pulse,    // single-cycle pulse, src_clk domain
    input  dst_clk,
    output dst_pulse     // single-cycle pulse, dst_clk domain
);

    // source domain: event -> toggle
    reg src_toggle = 1'b0;
    always @(posedge src_clk)
        if (src_pulse) src_toggle <= ~src_toggle;

    // crossing: level through two flops
    wire dst_toggle;
    sync2 u_sync (
        .clk      (dst_clk),
        .async_in (src_toggle),
        .sync_out (dst_toggle)
    );

    // destination domain: any edge of the toggle -> pulse
    reg dst_last = 1'b0;
    always @(posedge dst_clk)
        dst_last <= dst_toggle;

    assign dst_pulse = dst_toggle ^ dst_last;

endmodule
