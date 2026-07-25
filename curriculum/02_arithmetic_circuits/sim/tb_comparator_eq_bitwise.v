`timescale 1ns / 1ps

// Checks the bit-by-bit equality implementation against plain `a == b`
// directly (not against comparator.v's `eq` output, though that would be
// an equally valid check) - all 256 4-bit combinations.
module tb_comparator_eq_bitwise;

    localparam WIDTH = 4;

    reg  [WIDTH-1:0] a, b;
    wire             eq;
    integer errors = 0;
    integer ai, bi;

    comparator_eq_bitwise #(.WIDTH(WIDTH)) dut (.a(a), .b(b), .eq(eq));

    initial begin
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                a = ai[WIDTH-1:0]; b = bi[WIDTH-1:0];
                #1;
                if (eq !== (a == b)) begin
                    errors = errors + 1;
                    $display("FAIL a=%0d b=%0d got=%b exp=%b", a, b, eq, (a == b));
                end
            end
        end

        if (errors == 0) $display("PASS: tb_comparator_eq_bitwise - all 256 a/b combinations correct");
        else              $display("FAIL: tb_comparator_eq_bitwise - %0d error(s)", errors);
        $finish;
    end

endmodule
