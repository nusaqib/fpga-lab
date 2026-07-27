`timescale 1ns / 1ps

// Runtime-programmable power-of-two decimator: accumulate 2^n input
// pairs, emit their mean. n = 0 passes samples through (with one cycle
// of latency). Growth: 16 + 12 = 28 bits worst case, held in 32-bit
// accumulators, so the mean is exact and needs no saturation.
//
// Changing n mid-stream restarts the accumulation cleanly (the partial
// frame is discarded) - a glitch-free rate change matters when an
// operator retunes the loop rate on a running system.
module dec_pow2 (
    input                    clk,
    input                    rst,
    input      [3:0]         n,          // log2 decimation, 0..12
    input signed [15:0]      in_i,
    input signed [15:0]      in_q,
    input                    in_valid,
    output reg signed [15:0] out_i = 16'sd0,
    output reg signed [15:0] out_q = 16'sd0,
    output reg               out_valid = 1'b0
);
    reg signed [31:0] acc_i = 32'sd0, acc_q = 32'sd0;
    reg [12:0]        cnt = 13'd0;
    reg [3:0]         n_r = 4'd0;

    wire [12:0] last = (13'd1 << n_r) - 13'd1;

    always @(posedge clk) begin
        out_valid <= 1'b0;
        if (rst || n_r != n) begin
            n_r   <= n;
            acc_i <= 32'sd0;
            acc_q <= 32'sd0;
            cnt   <= 13'd0;
        end else if (in_valid) begin
            if (cnt == last) begin
                out_i     <= (acc_i + in_i) >>> n_r;
                out_q     <= (acc_q + in_q) >>> n_r;
                out_valid <= 1'b1;
                acc_i     <= 32'sd0;
                acc_q     <= 32'sd0;
                cnt       <= 13'd0;
            end else begin
                acc_i <= acc_i + in_i;
                acc_q <= acc_q + in_q;
                cnt   <= cnt + 13'd1;
            end
        end
    end
endmodule
