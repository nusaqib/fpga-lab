`timescale 1ns / 1ps

// 4-bit maximal-length LFSR (taps 4,3 - polynomial x^4 + x^3 + 1): a shift
// register whose feedback is the XOR of two taps, cycling through all 15
// nonzero states in a fixed pseudo-random-looking order. The all-zeros
// state is the classic LFSR lockup (0 XOR 0 feeds back 0 forever), which
// is why reset seeds to a nonzero value and the testbench proves the
// period is exactly 15, visiting every nonzero state once.
//
// LFSRs are everywhere: PRBS test patterns, scramblers, CRCs (module 27+
// territory), cheap "random" in hardware. This is the toy-sized version to
// internalize the mechanism.
module lfsr4 (
    input            clk,
    input            rst,
    input            en,
    output reg [3:0] q = 4'b0001
);

    wire feedback = q[3] ^ q[2];

    always @(posedge clk) begin
        if (rst)
            q <= 4'b0001;
        else if (en)
            q <= {q[2:0], feedback};
    end

endmodule
