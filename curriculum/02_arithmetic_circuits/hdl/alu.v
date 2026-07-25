`timescale 1ns / 1ps

// A minimal 4-function ALU (ADD/SUB/AND/OR), composing ripple_carry_adder
// rather than reimplementing addition. Subtraction reuses the same adder
// via two's complement: b - is inverted and cin forced to 1, so
// a + (~b) + 1 = a - b. `cout` for SUB therefore isn't a traditional
// "overflow" bit - it's the adder's carry-out for that same trick, which
// works out to mean "a >= b" (1 = no borrow, 0 = borrowed). See
// sim/tb_alu.v for the exact expected-value model this relies on, and the
// module README for a worked example.
module alu #(
    parameter WIDTH = 4
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    input  [1:0]       op,      // 2'b00=ADD 2'b01=SUB 2'b10=AND 2'b11=OR
    output [WIDTH-1:0] result,
    output             cout
);

    localparam [1:0] ALU_ADD = 2'b00;
    localparam [1:0] ALU_SUB = 2'b01;
    localparam [1:0] ALU_AND = 2'b10;
    localparam [1:0] ALU_OR  = 2'b11;

    wire [WIDTH-1:0] adder_b   = (op == ALU_SUB) ? ~b : b;
    wire             adder_cin = (op == ALU_SUB);
    wire [WIDTH-1:0] adder_sum;
    wire             adder_cout;

    ripple_carry_adder #(.WIDTH(WIDTH)) u_adder (
        .a    (a),
        .b    (adder_b),
        .cin  (adder_cin),
        .sum  (adder_sum),
        .cout (adder_cout)
    );

    reg [WIDTH-1:0] result_r;
    reg             cout_r;

    always @* begin
        case (op)
            ALU_ADD: begin result_r = adder_sum; cout_r = adder_cout; end
            ALU_SUB: begin result_r = adder_sum; cout_r = adder_cout; end
            ALU_AND: begin result_r = a & b;      cout_r = 1'b0;      end
            ALU_OR:  begin result_r = a | b;      cout_r = 1'b0;      end
            default: begin result_r = {WIDTH{1'bx}}; cout_r = 1'bx;   end
        endcase
    end

    assign result = result_r;
    assign cout   = cout_r;

endmodule
