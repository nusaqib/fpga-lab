`timescale 1ns / 1ps

// Serial-in, parallel-out shift register with parallel load - the bridge
// between "one bit at a time" and "a word at once", which is the essence
// of every serial protocol (UART, SPI, I2C) this curriculum meets later.
// MSB-first: serial bits enter at the bottom and march upward.
module shift_register #(
    parameter WIDTH = 4
) (
    input                  clk,
    input                  rst,
    input                  en,        // shift one bit this edge
    input                  serial_in,
    input                  load,      // parallel load (beats en)
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q = {WIDTH{1'b0}},
    output                 serial_out // MSB falls out as bits shift up
);

    assign serial_out = q[WIDTH-1];

    always @(posedge clk) begin
        if (rst)
            q <= {WIDTH{1'b0}};
        else if (load)
            q <= d;
        else if (en)
            q <= {q[WIDTH-2:0], serial_in};
    end

endmodule
