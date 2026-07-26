`timescale 1ns / 1ps

// Asynchronous FIFO - the CDC capstone, and the industry-standard design
// (Cummings' SNUG papers made it canonical). Same skeleton as module 07's
// fifo_sync: extra-bit pointers, pointer-compare flags. The new problem:
// each side must see the OTHER side's pointer through a synchronizer, and
// a binary counter can change many bits in one increment (0111->1000) -
// sampled mid-flight by the other domain, it reads garbage.
//
// The fix is GRAY CODE: successive values differ in exactly ONE bit, so a
// synchronizer can only ever return the old value or the new value -
// never a phantom third value. Both pointers are kept in binary (for
// addressing/arithmetic) and converted to Gray for the crossing:
//
//   bin -> gray:  g = b ^ (b >> 1)          (one XOR row)
//   flags compare GRAY pointers directly - full's classic top-two-bits-
//   inverted form falls out of how Gray code reflects at the halfway point.
//
// Conservatism note: each side sees a DELAYED version of the other's
// pointer (2-flop latency), so "full" can be briefly pessimistic and
// "empty" briefly stale. That's safe-by-construction: the writer thinks
// it's full a touch early, never late; the reader thinks it's empty a
// touch long, never pops garbage.
module fifo_async #(
    parameter WIDTH = 8,
    parameter DEPTH = 16               // power of two
) (
    // write side
    input              wclk,
    input              wrst,
    input              wr_en,
    input  [WIDTH-1:0] wdata,
    output             full,
    // read side
    input              rclk,
    input              rrst,
    input              rd_en,
    output reg [WIDTH-1:0] rdata,
    output             empty
);

    localparam AW = $clog2(DEPTH);

    function [AW:0] bin2gray(input [AW:0] b);
        bin2gray = b ^ (b >> 1);
    endfunction

    // ---- storage (write port in wclk, read port in rclk) ----
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // ---- write domain ----
    reg  [AW:0] wptr_bin = 0, wptr_gray = 0;
    wire [AW:0] rptr_gray_w;               // read pointer, seen from wclk
    wire        push = wr_en && !full;

    always @(posedge wclk) begin
        if (wrst) begin
            wptr_bin  <= 0;
            wptr_gray <= 0;
        end else if (push) begin
            mem[wptr_bin[AW-1:0]] <= wdata;
            wptr_bin  <= wptr_bin + 1'b1;
            wptr_gray <= bin2gray(wptr_bin + 1'b1);
        end
    end

    // full: next... current gray write pointer equals read pointer with
    // the top TWO bits inverted (the Gray-code image of "same address,
    // opposite lap").
    assign full = (wptr_gray == {~rptr_gray_w[AW:AW-1], rptr_gray_w[AW-2:0]});

    // ---- read domain ----
    reg  [AW:0] rptr_bin = 0, rptr_gray = 0;
    wire [AW:0] wptr_gray_r;               // write pointer, seen from rclk
    wire        pop = rd_en && !empty;

    always @(posedge rclk) begin
        if (rrst) begin
            rptr_bin  <= 0;
            rptr_gray <= 0;
        end else if (pop) begin
            rdata     <= mem[rptr_bin[AW-1:0]];
            rptr_bin  <= rptr_bin + 1'b1;
            rptr_gray <= bin2gray(rptr_bin + 1'b1);
        end
    end

    assign empty = (rptr_gray == wptr_gray_r);

    // ---- the crossings: Gray pointers through 2-flop synchronizers ----
    genvar i;
    generate
        for (i = 0; i <= AW; i = i + 1) begin : sync_ptrs
            sync2 u_w2r (.clk(rclk), .async_in(wptr_gray[i]), .sync_out(wptr_gray_r[i]));
            sync2 u_r2w (.clk(wclk), .async_in(rptr_gray[i]), .sync_out(rptr_gray_w[i]));
        end
    endgenerate
    // (Per-bit sync2 is safe HERE ONLY because Gray coding guarantees at
    // most one bit is in flight per transition - exactly the property that
    // makes multi-bit sync illegal in general.)

endmodule
