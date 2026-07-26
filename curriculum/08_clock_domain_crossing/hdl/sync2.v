`timescale 1ns / 1ps

// A two-flop synchronizer - structurally identical to pipeline2, but the
// *purpose* is different, and the ASYNC_REG attributes mark that purpose
// for the tools. This is the metastability introduction promised by the
// syllabus; module 08 (clock domain crossing) goes much deeper.
//
// Why it exists: a flip-flop samples reliably only if its input is stable
// around the clock edge (setup/hold window). An asynchronous input - a
// button, a signal from another clock domain - can change exactly in that
// window, leaving the flop's output metastable (neither 0 nor 1) for a
// while before it settles randomly. You can't prevent that; you can only
// give it time to resolve privately. Flop #1 absorbs the metastability,
// and by the time flop #2 samples one clock later, the value has (with
// overwhelming probability) settled. Nothing downstream ever sees the
// unsettled value.
//
// ASYNC_REG tells Vivado these two flops are a synchronizer: keep them
// physically close together (less wire delay = more settling time) and
// don't retime/optimize them apart.
module sync2 (
    input      clk,
    input      async_in,
    output     sync_out
);

    (* ASYNC_REG = "TRUE" *) reg meta   = 1'b0;
    (* ASYNC_REG = "TRUE" *) reg stable = 1'b0;

    always @(posedge clk) begin
        meta   <= async_in;
        stable <= meta;
    end

    assign sync_out = stable;

endmodule
