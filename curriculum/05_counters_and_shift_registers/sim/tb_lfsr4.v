`timescale 1ns / 1ps

// Proves the maximal-length property, not just "it shifts": starting from
// the seed, the LFSR must return to the seed after EXACTLY 15 steps
// (2^4 - 1), never hit all-zeros, and visit every one of the 15 nonzero
// states exactly once along the way.
module tb_lfsr4;

    reg  clk = 0, rst, en;
    wire [3:0] q;
    reg  [14:0] visited;   // one flag per nonzero state (q-1 indexes it)
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    lfsr4 dut (.clk(clk), .rst(rst), .en(en), .q(q));

    initial begin
        rst = 1; en = 0;
        @(negedge clk);
        rst = 0; en = 1;
        visited = 15'b0;

        for (i = 0; i < 15; i = i + 1) begin
            if (q == 4'b0000) begin
                errors = errors + 1;
                $display("FAIL step %0d: hit all-zeros lockup state", i);
            end else begin
                if (visited[q-1]) begin
                    errors = errors + 1;
                    $display("FAIL step %0d: state %b revisited before full period", i, q);
                end
                visited[q-1] = 1'b1;
            end
            @(negedge clk);
        end

        if (q !== 4'b0001) begin
            errors = errors + 1;
            $display("FAIL: after 15 steps q=%b, expected back at seed 0001", q);
        end
        if (visited !== 15'h7FFF) begin
            errors = errors + 1;
            $display("FAIL: not all 15 nonzero states visited (map=%b)", visited);
        end

        if (errors == 0) $display("PASS: tb_lfsr4 - maximal length: period 15, all nonzero states visited once");
        else              $display("FAIL: tb_lfsr4 - %0d error(s)", errors);
        $finish;
    end

endmodule
