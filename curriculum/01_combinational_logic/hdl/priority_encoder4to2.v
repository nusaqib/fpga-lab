`timescale 1ns / 1ps

// 4-to-2 priority encoder: reports the index of the highest-priority
// (highest bit index) asserted request line, plus a valid flag when at
// least one request is asserted. Written as an if/else-if chain rather than
// a case statement - that's what makes it a *priority* encoder instead of a
// plain one: req[3] always wins over req[2:0] even if several are asserted
// at once, because the chain checks it first and never falls through.
module priority_encoder4to2 (
    input      [3:0] req,
    output reg       valid,
    output reg [1:0] idx
);

    always @* begin
        if (req[3])      begin valid = 1'b1; idx = 2'd3; end
        else if (req[2]) begin valid = 1'b1; idx = 2'd2; end
        else if (req[1]) begin valid = 1'b1; idx = 2'd1; end
        else if (req[0]) begin valid = 1'b1; idx = 2'd0; end
        else             begin valid = 1'b0; idx = 2'd0; end
    end

endmodule
