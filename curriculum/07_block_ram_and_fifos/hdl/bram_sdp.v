`timescale 1ns / 1ps

// Simple-dual-port RAM written in the exact shape Vivado's synthesizer
// recognizes and maps onto a block RAM primitive: one write port, one read
// port, REGISTERED read output (that register is what makes it BRAM-able -
// ask for a same-cycle asynchronous read instead and you get LUTRAM,
// because real BRAM primitives simply don't have a combinational read
// path). Read latency is therefore 1 cycle, and everything downstream
// (the FIFO here, caches and buffers later) is designed around that.
//
// Collision semantics: if the read port reads the address the write port
// is writing THIS cycle, it returns the OLD data ("read-first" on a
// cross-port collision) - which is also what the hardware primitive does
// in its default mode. The testbench pins this down explicitly.
//
// (* ram_style = "block" *) makes the intent explicit rather than left to
// size heuristics - at this depth Vivado would likely infer BRAM anyway,
// but stating it means a regression (e.g. someone adding an async read
// path) fails loudly at synthesis instead of silently becoming LUTs.
module bram_sdp #(
    parameter WIDTH = 8,
    parameter DEPTH = 1024
) (
    input                        clk,
    // write port
    input                        we,
    input  [$clog2(DEPTH)-1:0]   waddr,
    input  [WIDTH-1:0]           wdata,
    // read port
    input                        re,
    input  [$clog2(DEPTH)-1:0]   raddr,
    output reg [WIDTH-1:0]       rdata
);

    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= wdata;
        if (re)
            rdata <= mem[raddr];
    end

endmodule
