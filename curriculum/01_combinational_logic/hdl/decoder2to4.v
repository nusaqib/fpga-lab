`timescale 1ns / 1ps

// 2-to-4 decoder: exactly one output bit is high, chosen by `in`. The
// default case matters even though every 2-bit value of `in` is already
// covered - it's what keeps `out` from inferring a latch if this were ever
// widened without updating every branch.
module decoder2to4 (
    input      [1:0] in,
    output reg [3:0] out
);

    always @* begin
        case (in)
            2'd0: out = 4'b0001;
            2'd1: out = 4'b0010;
            2'd2: out = 4'b0100;
            2'd3: out = 4'b1000;
            default: out = 4'b0000;
        endcase
    end

endmodule
