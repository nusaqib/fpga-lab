`timescale 1ns / 1ps

// Exhaustive over all 4-bit a x 4-bit b = 256 combinations. Also checks
// that exactly one of eq/lt/gt is ever asserted - a sanity property of a
// correct comparator regardless of what the individual bits should be.
module tb_comparator;

    localparam WIDTH = 4;

    reg  [WIDTH-1:0] a, b;
    wire             eq, lt, gt;
    integer errors = 0;
    integer ai, bi;

    comparator #(.WIDTH(WIDTH)) dut (.a(a), .b(b), .eq(eq), .lt(lt), .gt(gt));

    initial begin
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                a = ai[WIDTH-1:0]; b = bi[WIDTH-1:0];
                #1;
                if (eq !== (a == b) || lt !== (a < b) || gt !== (a > b)) begin
                    errors = errors + 1;
                    $display("FAIL a=%0d b=%0d got=(eq=%b,lt=%b,gt=%b)", a, b, eq, lt, gt);
                end
                if (eq + lt + gt != 1) begin
                    errors = errors + 1;
                    $display("FAIL a=%0d b=%0d exactly-one-flag violated: eq=%b lt=%b gt=%b", a, b, eq, lt, gt);
                end
            end
        end

        if (errors == 0) $display("PASS: tb_comparator - all 256 a/b combinations correct");
        else              $display("FAIL: tb_comparator - %0d error(s)", errors);
        $finish;
    end

endmodule
