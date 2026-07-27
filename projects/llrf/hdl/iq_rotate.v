`timescale 1ns / 1ps

// Complex rotation by a software-supplied unit vector:
//   out = in * (c + js)   ->  out_i = (i*c - q*s) >>> 15
//                             out_q = (i*s + q*c) >>> 15
// c/s are Q1.15 (software writes cos/sin of the loop phase; no CORDIC
// in the loop). Two pipeline stages (multiply, then add/shift/saturate)
// so the 307.2 MHz fabric clock closes comfortably in DSP48s.
// Saturation matters: |in| up to 1.0 times |(c,s)| up to 1.0 can round
// to just past +/-1.0 in Q1.15.
module iq_rotate (
    input                    clk,
    input                    rst,
    input signed [15:0]      c,          // Q1.15 cos
    input signed [15:0]      s,          // Q1.15 sin
    input signed [15:0]      in_i,
    input signed [15:0]      in_q,
    input                    in_valid,
    output reg signed [15:0] out_i = 16'sd0,
    output reg signed [15:0] out_q = 16'sd0,
    output reg               out_valid = 1'b0
);
    function signed [15:0] sat16(input signed [17:0] v);
        sat16 = (v > 18'sd32767)  ? 16'sd32767 :
                (v < -18'sd32768) ? -16'sd32768 : v[15:0];
    endfunction

    // stage 1: four products
    reg signed [31:0] p_ic = 32'sd0, p_qs = 32'sd0, p_is = 32'sd0, p_qc = 32'sd0;
    reg               v1 = 1'b0;
    // stage 2: combine
    wire signed [17:0] sum_i = (p_ic >>> 15) - (p_qs >>> 15);
    wire signed [17:0] sum_q = (p_is >>> 15) + (p_qc >>> 15);

    always @(posedge clk) begin
        if (rst) begin
            v1 <= 1'b0;
            out_valid <= 1'b0;
        end else begin
            v1 <= in_valid;
            if (in_valid) begin
                p_ic <= in_i * c;
                p_qs <= in_q * s;
                p_is <= in_i * s;
                p_qc <= in_q * c;
            end
            out_valid <= v1;
            if (v1) begin
                out_i <= sat16(sum_i);
                out_q <= sat16(sum_q);
            end
        end
    end
endmodule
