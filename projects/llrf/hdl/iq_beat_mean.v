`timescale 1ns / 1ps

// One 256-bit ADC beat (module 24's layout: [127:0] = 8x16-bit I,
// [255:128] = 8x16-bit Q) -> the beat's mean I and mean Q, one pair per
// fabric cycle. This is the first, cheapest decimation stage (/8): the
// LLRF loop cares about the cavity envelope, not 2457.6 Mcplx/s detail.
// Sum of eight 16-bit values is 19 bits; >>> 3 brings it back to 16 with
// no possibility of overflow, so no saturation is needed here.
module iq_beat_mean (
    input             clk,
    input             rst,
    input      [255:0] beat,
    input             beat_valid,
    output reg signed [15:0] mean_i = 16'sd0,
    output reg signed [15:0] mean_q = 16'sd0,
    output reg        mean_valid = 1'b0
);
    integer k;
    reg signed [18:0] sum_i, sum_q;

    always @* begin
        sum_i = 19'sd0;
        sum_q = 19'sd0;
        for (k = 0; k < 8; k = k + 1) begin
            sum_i = sum_i + $signed(beat[16*k       +: 16]);
            sum_q = sum_q + $signed(beat[128+16*k   +: 16]);
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            mean_valid <= 1'b0;
        end else begin
            mean_valid <= beat_valid;
            if (beat_valid) begin
                mean_i <= sum_i >>> 3;
                mean_q <= sum_q >>> 3;
            end
        end
    end
endmodule
