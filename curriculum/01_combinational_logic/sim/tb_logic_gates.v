`timescale 1ns / 1ps

// First testbench in the repo. The pattern every tb_*.v here follows:
// drive every input combination, compare against a hand-computed expected
// value, count mismatches, and print one PASS/FAIL summary line at the end
// that `make sim` greps for. No waveform viewer needed to know the result -
// though `make sim` still leaves a .wdb-free xsim run log you can extend
// with $dumpfile/$dumpvars if you want to look at waveforms later.
module tb_logic_gates;

    reg a, b;
    wire y_and, y_or, y_xor, y_nand;
    integer errors = 0;

    logic_gates dut (
        .a(a), .b(b),
        .y_and(y_and), .y_or(y_or), .y_xor(y_xor), .y_nand(y_nand)
    );

    task check(input exp_and, input exp_or, input exp_xor, input exp_nand);
        begin
            #1;
            if (y_and !== exp_and)   begin errors = errors + 1; $display("FAIL and  a=%b b=%b got=%b exp=%b", a, b, y_and, exp_and); end
            if (y_or  !== exp_or)    begin errors = errors + 1; $display("FAIL or   a=%b b=%b got=%b exp=%b", a, b, y_or, exp_or); end
            if (y_xor !== exp_xor)   begin errors = errors + 1; $display("FAIL xor  a=%b b=%b got=%b exp=%b", a, b, y_xor, exp_xor); end
            if (y_nand !== exp_nand) begin errors = errors + 1; $display("FAIL nand a=%b b=%b got=%b exp=%b", a, b, y_nand, exp_nand); end
        end
    endtask

    initial begin
        a = 0; b = 0; check(0, 0, 0, 1);
        a = 0; b = 1; check(0, 1, 1, 1);
        a = 1; b = 0; check(0, 1, 1, 1);
        a = 1; b = 1; check(1, 1, 0, 0);

        if (errors == 0) $display("PASS: tb_logic_gates - all 4 input combinations correct");
        else              $display("FAIL: tb_logic_gates - %0d error(s)", errors);
        $finish;
    end

endmodule
