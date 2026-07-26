`timescale 1ns / 1ps

// One-cycle pulse on each rising edge of a (clean, synchronous) input:
// remember last cycle's value, fire when it was 0 and is now 1. Three
// lines that complete the button-input stack:
//
//   raw pin -> sync2 -> debounce -> edge_detect -> "exactly one pulse per press"
//
// Feed this a *bouncy* input instead and you get one pulse per bounce -
// tb_button_pulse.v demonstrates exactly that failure, which is the whole
// argument for the debouncer.
module edge_detect (
    input  clk,
    input  level_in,
    output pulse_out
);

    reg last;

    always @(posedge clk)
        last <= level_in;

    assign pulse_out = level_in & ~last;

endmodule
