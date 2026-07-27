`timescale 1ns / 1ps

// The reference DUT: module 07's synchronous FIFO, depth 8, with the
// extra-pointer-bit full/empty discipline and a REGISTERED count whose
// next value is computed combinationally - flags derive from what the
// state is ABOUT to be, never from what it was (see fifo8_buggy.v for
// the alternative and its consequences).
module fifo8 #(
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
    reg [3:0] wptr = 0, rptr = 0;    // extra MSB disambiguates full/empty

    assign full  = (wptr[2:0] == rptr[2:0]) && (wptr[3] != rptr[3]);
    assign empty = (wptr == rptr);
    assign rdata = mem[rptr[2:0]];

    wire do_push = push && !full;
    wire do_pop  = pop  && !empty;

    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0;
            rptr <= 0;
            count <= 0;
        end else begin
            if (do_push) begin
                mem[wptr[2:0]] <= wdata;
                wptr <= wptr + 1'b1;
            end
            if (do_pop)
                rptr <= rptr + 1'b1;
            count <= count + do_push - do_pop;
        end
    end

endmodule
