`timescale 1ns / 1ps

// The entire "design": wire each switch straight to an LED. No clock, no
// registers - purely combinational. The point of this module isn't the
// logic (there isn't any), it's proving that source -> constraints ->
// synthesis -> implementation -> bitstream -> programmed hardware works,
// before anything more interesting is layered on top.
module passthrough #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] sw,
    output [WIDTH-1:0] led
);

    assign led = sw;

endmodule
