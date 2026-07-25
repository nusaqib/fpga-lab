`timescale 1ns / 1ps

// Exhaustive over all 4-bit a x 4-bit b x cin = 16*16*2 = 512 combinations,
// checked against plain 5-bit integer arithmetic (the {cout,sum} concat is
// exactly a+b+cin with no truncation, since WIDTH+1 bits is always enough
// to hold the sum of two WIDTH-bit numbers plus a carry-in).
module tb_ripple_carry_adder;

    localparam WIDTH = 4;

    reg  [WIDTH-1:0] a, b;
    reg              cin;
    wire [WIDTH-1:0] sum;
    wire             cout;
    reg  [WIDTH:0]   expected;
    integer errors = 0;
    integer ai, bi, ci;

    ripple_carry_adder #(.WIDTH(WIDTH)) dut (
        .a(a), .b(b), .cin(cin), .sum(sum), .cout(cout)
    );

    initial begin
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                for (ci = 0; ci < 2; ci = ci + 1) begin
                    a = ai[WIDTH-1:0]; b = bi[WIDTH-1:0]; cin = ci[0];
                    #1;
                    expected = a + b + cin;
                    if ({cout, sum} !== expected) begin
                        errors = errors + 1;
                        $display("FAIL a=%0d b=%0d cin=%b got=%0d exp=%0d", a, b, cin, {cout, sum}, expected);
                    end
                end
            end
        end

        if (errors == 0) $display("PASS: tb_ripple_carry_adder - all 512 a/b/cin combinations correct");
        else              $display("FAIL: tb_ripple_carry_adder - %0d error(s)", errors);
        $finish;
    end

endmodule
