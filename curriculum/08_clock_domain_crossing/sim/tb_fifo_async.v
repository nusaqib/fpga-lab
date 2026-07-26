`timescale 1ns / 1ps

// The async FIFO under two genuinely unrelated clocks, both directions
// (fast writer/slow reader and slow writer/fast reader - two instances),
// each against its own SV queue model. Writers push random data whenever
// not full; readers pop whenever not empty; every popped word must match
// the queue head. The fast-writer instance guarantees backpressure gets
// exercised (full asserts), the slow-writer one guarantees empty does.
module tb_fifo_async;

    localparam WIDTH = 8, DEPTH = 16;
    localparam WORDS = 2000;

    reg clk_fast = 0, clk_slow = 0;
    always #3.5  clk_fast = ~clk_fast;   // 7ns
    always #5.65 clk_slow = ~clk_slow;   // 11.3ns

    integer errors = 0;

    // ================= instance 1: fast writer -> slow reader ===========
    reg              wr1 = 0;
    reg  [WIDTH-1:0] wd1;
    wire             full1, empty1;
    reg              rd1 = 0;
    wire [WIDTH-1:0] rdat1;
    byte model1[$];
    integer pushed1 = 0, popped1 = 0;
    reg pop_pend1 = 0; byte pop_exp1;
    reg saw_full1 = 0;

    fifo_async #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut1 (
        .wclk(clk_fast), .wrst(1'b0), .wr_en(wr1), .wdata(wd1), .full(full1),
        .rclk(clk_slow), .rrst(1'b0), .rd_en(rd1), .rdata(rdat1), .empty(empty1)
    );

    // writer (fast domain)
    always @(negedge clk_fast) begin
        if (full1) saw_full1 = 1;
        if (pushed1 < WORDS && !full1) begin
            wd1 = $random;
            wr1 = 1;
            model1.push_back(wd1);
            pushed1 = pushed1 + 1;
        end else begin
            wr1 = 0;
        end
    end

    // reader (slow domain) - checks one cycle after an accepted pop
    always @(negedge clk_slow) begin
        if (pop_pend1) begin
            if (rdat1 !== pop_exp1) begin
                errors = errors + 1;
                $display("FAIL fifo1 word %0d: got %h exp %h", popped1, rdat1, pop_exp1);
            end
            popped1 = popped1 + 1;
            pop_pend1 = 0;
        end
        if (!empty1 && model1.size() > 0) begin
            rd1 = 1;
            pop_exp1 = model1.pop_front();
            pop_pend1 = 1;
        end else begin
            rd1 = 0;
        end
    end

    // ================= instance 2: slow writer -> fast reader ===========
    reg              wr2 = 0;
    reg  [WIDTH-1:0] wd2;
    wire             full2, empty2;
    reg              rd2 = 0;
    wire [WIDTH-1:0] rdat2;
    byte model2[$];
    integer pushed2 = 0, popped2 = 0;
    reg pop_pend2 = 0; byte pop_exp2;

    fifo_async #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut2 (
        .wclk(clk_slow), .wrst(1'b0), .wr_en(wr2), .wdata(wd2), .full(full2),
        .rclk(clk_fast), .rrst(1'b0), .rd_en(rd2), .rdata(rdat2), .empty(empty2)
    );

    always @(negedge clk_slow) begin
        if (pushed2 < WORDS && !full2) begin
            wd2 = $random;
            wr2 = 1;
            model2.push_back(wd2);
            pushed2 = pushed2 + 1;
        end else begin
            wr2 = 0;
        end
    end

    always @(negedge clk_fast) begin
        if (pop_pend2) begin
            if (rdat2 !== pop_exp2) begin
                errors = errors + 1;
                $display("FAIL fifo2 word %0d: got %h exp %h", popped2, rdat2, pop_exp2);
            end
            popped2 = popped2 + 1;
            pop_pend2 = 0;
        end
        if (!empty2 && model2.size() > 0) begin
            rd2 = 1;
            pop_exp2 = model2.pop_front();
            pop_pend2 = 1;
        end else begin
            rd2 = 0;
        end
    end

    // ================= scoreboard =======================================
    initial begin
        wait (popped1 == WORDS && popped2 == WORDS);
        if (!saw_full1) begin
            errors = errors + 1;
            $display("FAIL: fast-writer FIFO never went full - backpressure untested");
        end
        if (errors == 0) $display("PASS: tb_fifo_async - %0d words each direction across unrelated clocks, in order, backpressure exercised", WORDS);
        else              $display("FAIL: tb_fifo_async - %0d error(s)", errors);
        $finish;
    end

    // watchdog
    initial begin
        #4_000_000;
        $display("FAIL: tb_fifo_async - watchdog timeout (popped1=%0d popped2=%0d)", popped1, popped2);
        $finish;
    end

endmodule
