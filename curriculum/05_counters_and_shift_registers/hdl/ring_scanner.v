`timescale 1ns / 1ps

// A one-hot bit circulating through WIDTH positions - a ring counter,
// a.k.a. the "Knight Rider" scanner when wired to LEDs. Also the first
// self-correcting register in the curriculum: if the state somehow ends up
// all-zeros (or otherwise loses its single hot bit), it reseeds rather
// than circulating garbage forever. Worth noticing: `^q` (reduction XOR)
// is 1 exactly when an odd number of bits are set, so checking
// "exactly one bit hot" for a ring counter is cheap - here we keep it
// simpler and just reseed when the hot bit is absent entirely.
module ring_scanner #(
    parameter WIDTH = 4
) (
    input              clk,
    input              rst,
    input              en,
    output reg [WIDTH-1:0] q = {{WIDTH-1{1'b0}}, 1'b1}
);

    always @(posedge clk) begin
        if (rst)
            q <= {{WIDTH-1{1'b0}}, 1'b1};
        else if (en) begin
            if (q == {WIDTH{1'b0}})
                q <= {{WIDTH-1{1'b0}}, 1'b1};       // self-correct
            else
                q <= {q[WIDTH-2:0], q[WIDTH-1]};    // rotate
        end
    end

endmodule
