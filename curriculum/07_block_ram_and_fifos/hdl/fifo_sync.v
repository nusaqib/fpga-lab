`timescale 1ns / 1ps

// Synchronous (single-clock) FIFO - the standard pointer-based build on
// top of a dual-port RAM. The trick worth internalizing is the EXTRA
// POINTER BIT: read and write pointers are $clog2(DEPTH)+1 bits wide, one
// more than the RAM address needs. Pointers equal in ALL bits = empty;
// equal in address bits but differing in the top bit = the write pointer
// has lapped the read pointer exactly once = full. Without that bit,
// rd==wr is ambiguous between completely empty and completely full, and
// every workaround (keeping one slot unused, a separate count register in
// the datapath) is worse.
//
// Interface protocol ("valid-gated"): a push is (wr_en && !full), a pop is
// (rd_en && !empty) - asserting wr_en while full or rd_en while empty is
// simply ignored, never corrupting state. rdata is registered with one
// cycle of latency after an accepted pop, matching the BRAM read register.
//
// This FIFO is SINGLE-CLOCK ONLY. The pointer-compare logic silently
// assumes both sides see each other's pointers instantly, which is only
// true inside one clock domain - carry this design across two clocks and
// full/empty lie to you. The asynchronous FIFO that survives two clocks
// (Gray-coded pointers, synchronizers) is module 08's capstone.
module fifo_sync #(
    parameter WIDTH = 8,
    parameter DEPTH = 16               // power of two
) (
    input              clk,
    input              rst,
    input              wr_en,
    input  [WIDTH-1:0] wdata,
    input              rd_en,
    output reg [WIDTH-1:0] rdata,
    output             full,
    output             empty,
    output [$clog2(DEPTH):0] count
);

    localparam AW = $clog2(DEPTH);

    reg [AW:0] wptr = 0, rptr = 0;     // one extra bit each - see header

    wire push = wr_en && !full;
    wire pop  = rd_en && !empty;

    reg [WIDTH-1:0] mem [0:DEPTH-1];   // small/fast FIFOs often map to
                                       // LUTRAM; left to size heuristics

    always @(posedge clk) begin
        if (push)
            mem[wptr[AW-1:0]] <= wdata;
        if (pop)
            rdata <= mem[rptr[AW-1:0]];
    end

    always @(posedge clk) begin
        if (rst) begin
            wptr <= 0;
            rptr <= 0;
        end else begin
            if (push) wptr <= wptr + 1'b1;
            if (pop)  rptr <= rptr + 1'b1;
        end
    end

    assign empty = (wptr == rptr);
    assign full  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
    assign count = wptr - rptr;        // extra bit makes this work at full

endmodule
