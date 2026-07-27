`timescale 1ns / 1ps

// The directed testbench - the kind every earlier module used, written
// carefully, checking everything it does... and it PASSES ON THE BUGGY
// FIFO TOO. That's not a failure of this bench; it's the ceiling of the
// methodology: directed tests verify the scenarios their author thought
// of, and this author (like most) pushes, politely waits, and checks.
// The planted bug needs back-to-back pushes exactly at the full
// boundary - a scenario nobody "thinks of" until it eats real data.
//
// Verdict logic: correct FIFO must pass everything. The buggy FIFO's
// result is *reported* - if directed testing suddenly caught it, this
// bench FAILS, because the module's whole premise would be wrong.
module tb_fifo_directed;

    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;

    // two identical stimulus buses, one per DUT
    reg push = 0, pop = 0;
    reg [7:0] wdata = 0;

    wire g_full, g_empty, b_full, b_empty;
    wire [7:0] g_rdata, b_rdata;
    wire [3:0] g_count, b_count;

    fifo8 u_good (
        .clk(clk), .rst(rst), .push(push), .wdata(wdata),
        .full(g_full), .pop(pop), .rdata(g_rdata), .empty(g_empty),
        .count(g_count)
    );
    fifo8_buggy u_bug (
        .clk(clk), .rst(rst), .push(push), .wdata(wdata),
        .full(b_full), .pop(pop), .rdata(b_rdata), .empty(b_empty),
        .count(b_count)
    );

    integer g_errors = 0, b_errors = 0;
    integer i;

    // polite, one-op-at-a-time stimulus: push, settle, check
    task push1(input [7:0] d);
        begin
            @(negedge clk);
            push <= 1; wdata <= d;
            @(negedge clk);
            push <= 0;
        end
    endtask

    task pop1(input [7:0] expect_d);
        begin
            @(negedge clk);
            if (g_rdata !== expect_d) begin
                $display("GOOD mismatch: got %0d want %0d", g_rdata, expect_d);
                g_errors = g_errors + 1;
            end
            if (b_rdata !== expect_d)
                b_errors = b_errors + 1;
            pop <= 1;
            @(negedge clk);
            pop <= 0;
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;

        // fill to full, checking the flag walks up correctly
        for (i = 1; i <= 8; i = i + 1)
            push1(i[7:0]);
        @(negedge clk);
        if (!g_full)  begin $display("GOOD: full not set");  g_errors = g_errors + 1; end
        if (!b_full)  b_errors = b_errors + 1;

        // drain completely, data in order
        for (i = 1; i <= 8; i = i + 1)
            pop1(i[7:0]);
        @(negedge clk);
        if (!g_empty) begin $display("GOOD: empty not set"); g_errors = g_errors + 1; end
        if (!b_empty) b_errors = b_errors + 1;

        // interleaved push/pop at low occupancy
        push1(8'hA0);
        push1(8'hA1);
        pop1(8'hA0);
        push1(8'hA2);
        pop1(8'hA1);
        pop1(8'hA2);

        $display("directed vs correct FIFO: %0d errors", g_errors);
        $display("directed vs BUGGY FIFO:   %0d errors  <- the lesson", b_errors);
        if (g_errors == 0 && b_errors == 0)
            $display("PASS: directed suite green on both - including the broken one");
        else if (g_errors != 0)
            $display("FAIL: correct FIFO failed directed tests");
        else
            $display("FAIL: premise broken - directed testing caught the planted bug");
        $finish;
    end

endmodule
