`timescale 1ns / 1ps

// Exhaustive over all 8 (a,b,cin) combinations.
module tb_full_adder;

    reg  a, b, cin;
    wire sum, cout;
    reg  exp_sum, exp_cout;
    integer errors = 0;
    integer i;

    full_adder dut (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            {a, b, cin} = i[2:0];
            #1;
            {exp_cout, exp_sum} = a + b + cin;
            if (sum !== exp_sum || cout !== exp_cout) begin
                errors = errors + 1;
                $display("FAIL a=%b b=%b cin=%b got=(cout=%b,sum=%b) exp=(cout=%b,sum=%b)",
                          a, b, cin, cout, sum, exp_cout, exp_sum);
            end
        end

        if (errors == 0) $display("PASS: tb_full_adder - all 8 input combinations correct");
        else              $display("FAIL: tb_full_adder - %0d error(s)", errors);
        $finish;
    end

endmodule
