`timescale 1ns / 1ps

// Hardware demo for priority_encoder4to2: all four switches are request
// lines. led[1:0] shows the index of the highest-priority switch that's on;
// led[2] shows whether any switch is on at all. Try sw = 4'b1010 and
// confirm the index shown is 3, not 1 - that's the "priority" part.
module priority_encoder_top (
    input  [3:0] sw,
    output [3:0] led
);

    wire       valid;
    wire [1:0] idx;

    priority_encoder4to2 u_enc (
        .req   (sw),
        .valid (valid),
        .idx   (idx)
    );

    assign led[1:0] = idx;
    assign led[2]   = valid;
    assign led[3]   = 1'b0;

endmodule
