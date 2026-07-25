`timescale 1ns / 1ps

// Two DUTs, one testbench: cla_adder4 is checked against plain arithmetic
// (same 512-case exhaustive sweep as tb_ripple_carry_adder), *and* directly
// against a ripple_carry_adder#(.WIDTH(4)) instance fed the exact same
// inputs every cycle. That second check is the concrete version of "these
// are structurally different but functionally identical" - if the two
// disagree on even one of 512 cases, something's wrong with one of them.
module tb_cla_adder4;

    reg  [3:0] a, b;
    reg        cin;
    wire [3:0] cla_sum, rca_sum;
    wire       cla_cout, rca_cout;
    reg  [4:0] expected;
    integer errors = 0;
    integer ai, bi, ci;

    cla_adder4 dut_cla (
        .a(a), .b(b), .cin(cin), .sum(cla_sum), .cout(cla_cout)
    );

    ripple_carry_adder #(.WIDTH(4)) dut_rca (
        .a(a), .b(b), .cin(cin), .sum(rca_sum), .cout(rca_cout)
    );

    initial begin
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                for (ci = 0; ci < 2; ci = ci + 1) begin
                    a = ai[3:0]; b = bi[3:0]; cin = ci[0];
                    #1;
                    expected = a + b + cin;

                    if ({cla_cout, cla_sum} !== expected) begin
                        errors = errors + 1;
                        $display("FAIL(arith) a=%0d b=%0d cin=%b cla_got=%0d exp=%0d", a, b, cin, {cla_cout, cla_sum}, expected);
                    end
                    if ({cla_cout, cla_sum} !== {rca_cout, rca_sum}) begin
                        errors = errors + 1;
                        $display("FAIL(vs rca) a=%0d b=%0d cin=%b cla=%0d rca=%0d", a, b, cin, {cla_cout, cla_sum}, {rca_cout, rca_sum});
                    end
                end
            end
        end

        if (errors == 0) $display("PASS: tb_cla_adder4 - matches arithmetic and ripple_carry_adder on all 512 combinations");
        else              $display("FAIL: tb_cla_adder4 - %0d error(s)", errors);
        $finish;
    end

endmodule
