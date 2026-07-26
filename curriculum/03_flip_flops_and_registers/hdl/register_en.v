`timescale 1ns / 1ps

// A WIDTH-bit register with clock enable - dff_en, vectorized. This is the
// single most common sequential element in real designs: state that updates
// only when told to.
module register_en #(
    parameter WIDTH = 4
) (
    input                  clk,
    input                  rst,
    input                  en,
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk) begin
        if (rst)     q <= {WIDTH{1'b0}};
        else if (en) q <= d;
    end

endmodule
