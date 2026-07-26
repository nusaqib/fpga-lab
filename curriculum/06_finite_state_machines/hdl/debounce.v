`timescale 1ns / 1ps

// Debouncer: the output only changes after the (already synchronized)
// input has held a new value for STABLE_COUNT consecutive clock cycles.
// Mechanical switch contacts literally bounce - a single press can look
// like dozens of edges over a few milliseconds - so anything
// edge-triggered downstream (module 05's counters, module 06's FSMs) needs
// this in front of it.
//
// Structure: sync2 first (metastability, module 03), then a counter that
// restarts every time the input disagrees with the current output and
// commits the new value once it survives the full count. 10ms at 100MHz
// (the default) comfortably outlasts typical contact bounce.
module debounce #(
    parameter STABLE_COUNT = 1_000_000   // 10ms at 100MHz
) (
    input  clk,
    input  rst,
    input  noisy_in,     // raw asynchronous button/switch pin
    output reg clean_out
);

    wire in_s;

    sync2 u_sync (
        .clk      (clk),
        .async_in (noisy_in),
        .sync_out (in_s)
    );

    reg [$clog2(STABLE_COUNT)-1:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count     <= 0;
            clean_out <= 1'b0;
        end else if (in_s == clean_out) begin
            count <= 0;                      // nothing to prove
        end else if (count == STABLE_COUNT-1) begin
            count     <= 0;
            clean_out <= in_s;               // survived: commit
        end else begin
            count <= count + 1;              // still proving itself
        end
    end

endmodule
