`timescale 1ns / 1ps

// The three D flip-flop variants worth knowing apart. All three capture `d`
// on the rising clock edge - they differ only in how reset behaves, which
// is a genuine hardware difference (it changes what logic the reset signal
// touches), not a style preference.

// Async reset: reset takes effect the moment rst asserts, clock or no
// clock - rst is in the sensitivity list. This is how you knock a design
// into a known state even when clocks aren't running yet.
module dff_async_reset (
    input      clk,
    input      rst,
    input      d,
    output reg q
);
    always @(posedge clk or posedge rst) begin
        if (rst) q <= 1'b0;
        else     q <= d;
    end
endmodule

// Sync reset: reset is just another input sampled at the clock edge - note
// the sensitivity list has only the clock. Synthesizes into the D-path
// logic rather than the flop's dedicated reset pin.
module dff_sync_reset (
    input      clk,
    input      rst,
    input      d,
    output reg q
);
    always @(posedge clk) begin
        if (rst) q <= 1'b0;
        else     q <= d;
    end
endmodule

// Clock enable: only captures when en is high; otherwise holds. This is
// THE idiom for "do something slower than the clock" on an FPGA - you
// almost never generate a slower clock, you enable a fast one less often
// (module 04 builds exactly that).
module dff_en (
    input      clk,
    input      rst,
    input      en,
    input      d,
    output reg q
);
    always @(posedge clk) begin
        if (rst)     q <= 1'b0;
        else if (en) q <= d;
    end
endmodule
