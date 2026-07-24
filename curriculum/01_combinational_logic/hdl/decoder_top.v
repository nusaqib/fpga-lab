`timescale 1ns / 1ps

// Hardware demo for decoder2to4: sw[1:0] is a 2-bit address, and exactly
// one LED lights up for each of the four possible values.
module decoder_top (
    input  [3:0] sw,
    output [3:0] led
);

    decoder2to4 u_decoder (
        .in  (sw[1:0]),
        .out (led)
    );

endmodule
