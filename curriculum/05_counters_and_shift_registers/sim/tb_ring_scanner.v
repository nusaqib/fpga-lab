`timescale 1ns / 1ps

// Checks: exactly one bit hot at all times, hot bit advances one position
// per enabled cycle with wraparound, and the self-correction path (force
// all-zeros via hierarchical assignment) reseeds instead of sticking.
module tb_ring_scanner;

    localparam WIDTH = 4;

    reg  clk = 0, rst, en;
    wire [WIDTH-1:0] q;
    reg  [WIDTH-1:0] expected;
    integer errors = 0;
    integer i;

    // $countones is SystemVerilog; benches compile with -sv already.
    always #5 clk = ~clk;

    ring_scanner #(.WIDTH(WIDTH)) dut (.clk(clk), .rst(rst), .en(en), .q(q));

    initial begin
        rst = 1; en = 0;
        @(negedge clk);
        rst = 0; en = 1;

        expected = 4'b0001;
        for (i = 0; i < 3*WIDTH; i = i + 1) begin
            if (q !== expected) begin
                errors = errors + 1;
                $display("FAIL step %0d: q=%b exp=%b", i, q, expected);
            end
            if ($countones(q) !== 1) begin
                errors = errors + 1;
                $display("FAIL step %0d: q=%b not one-hot", i, q);
            end
            @(negedge clk);
            expected = {expected[WIDTH-2:0], expected[WIDTH-1]};
        end

        // Self-correction: force the lockup state.
        en = 0;
        force dut.q = {WIDTH{1'b0}};
        @(negedge clk);
        release dut.q;
        en = 1;
        @(negedge clk);   // one enabled edge to recover
        @(negedge clk);
        if ($countones(q) !== 1) begin
            errors = errors + 1;
            $display("FAIL self-correct: q=%b after recovery, expected one-hot", q);
        end

        if (errors == 0) $display("PASS: tb_ring_scanner - one-hot rotation with wrap + self-corrects from all-zeros");
        else              $display("FAIL: tb_ring_scanner - %0d error(s)", errors);
        $finish;
    end

endmodule
