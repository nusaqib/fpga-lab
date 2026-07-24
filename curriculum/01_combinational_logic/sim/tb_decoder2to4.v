`timescale 1ns / 1ps

module tb_decoder2to4;

    reg  [1:0] in;
    wire [3:0] out;
    reg  [3:0] expected;
    integer errors = 0;
    integer i;

    decoder2to4 dut (.in(in), .out(out));

    initial begin
        for (i = 0; i < 4; i = i + 1) begin
            in = i[1:0];
            #1;
            expected = 4'b0001 << i;
            if (out !== expected) begin
                errors = errors + 1;
                $display("FAIL in=%0d got=%b exp=%b", i, out, expected);
            end
        end

        if (errors == 0) $display("PASS: tb_decoder2to4 - all 4 input values correct");
        else              $display("FAIL: tb_decoder2to4 - %0d error(s)", errors);
        $finish;
    end

endmodule
