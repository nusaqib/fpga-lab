`timescale 1ns / 1ps

// 4-tap FIR filter, TRANSPOSED direct form, Q1.15 fixed point throughout.
//
// Fixed-point format (the real subject of this module):
//   samples & coefficients: Q1.15 - 1 sign bit, 15 fraction bits, so
//   int16 value v represents v / 32768.0, range [-1.0, +1.0).
//   products: Q2.30 (sign+int bit, 30 fraction) in 32 bits;
//   accumulation of 4 products needs 2 growth bits -> 34-bit Q4.30;
//   output: round to nearest (add half-LSB, arithmetic shift right 15)
//   then SATURATE back into int16 - a full-scale step into these
//   0.25-sum-to-1.0 coefficients lands exactly on +1.0, which Q1.15
//   cannot represent, so the output clips to 0x7FFF: deliberate, visible
//   saturation instead of silent wraparound to -1.0.
//
// Transposed form: the input broadcasts to all four multipliers and the
// products flow down an adder chain with a register between stages. This
// is the shape that maps directly onto the DSP48's internal structure
// (multiplier -> post-adder -> cascade to the next slice), which is why
// `make ooc` shows this module using real DSP48E1 primitives instead of
// LUT multipliers. (* use_dsp = "yes" *) makes the intent explicit.
module fir4_transposed (
    input                     clk,
    input                     rst,
    input                     in_valid,
    input  signed [15:0]      in_sample,    // Q1.15
    output reg                out_valid,
    output reg signed [15:0]  out_sample    // Q1.15
);

    // Symmetric low-pass {0.1, 0.4, 0.4, 0.1} in Q1.15; sum = 32768 = 1.0
    // exactly, preserving the saturating-step lesson. NOT powers of two on
    // purpose: the first draft used 0.25 x4, and multiplying by 2^13 is
    // free (a shift) - synthesis used zero multipliers and the whole
    // DSP48 lesson evaporated. Constant choice changes the hardware.
    localparam signed [15:0] C0 = 16'sd3277;
    localparam signed [15:0] C1 = 16'sd13107;
    localparam signed [15:0] C2 = 16'sd13107;
    localparam signed [15:0] C3 = 16'sd3277;

    (* use_dsp = "yes" *) reg signed [33:0] acc1, acc2, acc3;  // Q4.30 chain
    wire signed [31:0] p0 = in_sample * C0;   // Q2.30
    wire signed [31:0] p1 = in_sample * C1;
    wire signed [31:0] p2 = in_sample * C2;
    wire signed [31:0] p3 = in_sample * C3;

    // round-to-nearest then saturate Q4.30 -> Q1.15
    function signed [15:0] rnd_sat(input signed [33:0] a);
        reg signed [33:0] rounded;
        begin
            rounded = (a + 34'sd16384) >>> 15;   // +half LSB, then >>15
            if (rounded > 34'sd32767)       rnd_sat = 16'sd32767;
            else if (rounded < -34'sd32768) rnd_sat = -16'sd32768;
            else                            rnd_sat = rounded[15:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            acc1 <= 0; acc2 <= 0; acc3 <= 0;
            out_valid  <= 1'b0;
            out_sample <= 16'sd0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                // transposed chain: newest product enters at the far end,
                // partial sums shift toward the output
                acc3 <= p3;
                acc2 <= acc3 + p2;
                acc1 <= acc2 + p1;
                out_sample <= rnd_sat(acc1 + p0);
            end
        end
    end

endmodule
