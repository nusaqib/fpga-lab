`timescale 1ns / 1ps

// THE PLANTED BUG - deliberately, for module 28.
//
// This FIFO REGISTERS its `full` flag from the current count ("one flop
// for timing!"): after the push that makes it full, `full` doesn't
// assert until the following cycle. A second push arriving back-to-back
// in that window is accepted, count reaches 9, the 3-bit write pointer
// wraps, and the oldest entry is silently overwritten - worse, at
// count 9 the `count == 8` compare is false, so `full` DEASSERTS again.
//
// Why this bug and not something sillier: it's a real-world classic
// (flags must be derived from next-state, not state), it never crashes,
// corrupts exactly one entry, and only under BACK-TO-BACK pushes at the
// full boundary - polite directed tests that push, wait, and check
// never see it. That's the point of the module.
module fifo8_buggy #(
    parameter W = 8
) (
    input          clk,
    input          rst,
    input          push,
    input  [W-1:0] wdata,
    output         full,
    input          pop,
    output [W-1:0] rdata,
    output         empty,
    output reg [3:0] count = 0
);

    reg [W-1:0] mem [0:7];
    reg [2:0] wptr = 0, rptr = 0;

    reg full_r = 1'b0;
    assign full  = full_r;            // <- one cycle stale at the boundary
    assign empty = (count == 4'd0);
    assign rdata = mem[rptr];

    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0;
            rptr <= 0;
            count <= 0;
            full_r <= 0;
        end else begin
            if (do_push) begin
                mem[wptr] <= wdata;
                wptr <= wptr + 1'b1;
            end
            if (do_pop)
                rptr <= rptr + 1'b1;
            count <= count + do_push - do_pop;
            // the bug: registered from CURRENT count, not next state
            full_r <= (count == 4'd8);
        end
    end

endmodule
