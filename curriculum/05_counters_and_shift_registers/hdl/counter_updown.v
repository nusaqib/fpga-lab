`timescale 1ns / 1ps

// Up/down counter with enable and load - the four controls that cover
// nearly every counter you'll ever need, with an explicit priority order:
// rst > load > en. Writing the priority as nested if/else (rather than
// hoping) is the habit; the testbench checks all four behaviors and the
// priority itself.
module counter_updown #(
    parameter WIDTH = 4
) (
    input                  clk,
    input                  rst,
    input                  en,
    input                  up,       // 1 = count up, 0 = count down
    input                  load,     // load `d` next edge (beats en)
    input      [WIDTH-1:0] d,
    output reg [WIDTH-1:0] count = {WIDTH{1'b0}}
);

    always @(posedge clk) begin
        if (rst)
            count <= {WIDTH{1'b0}};
        else if (load)
            count <= d;
        else if (en)
            count <= up ? count + 1'b1 : count - 1'b1;
    end

endmodule
