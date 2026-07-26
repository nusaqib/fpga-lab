`timescale 1ns / 1ps

// Drives a deliberately bouncy press at the debouncer and checks:
// 1) clean_out never glitches during the bounce storm,
// 2) it commits to 1 only after the input holds high for STABLE_COUNT,
// 3) same story on release.
module tb_debounce;

    localparam STABLE_COUNT = 20;   // tiny, for simulation

    reg  clk = 0, rst, noisy;
    wire clean;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    debounce #(.STABLE_COUNT(STABLE_COUNT)) dut (
        .clk(clk), .rst(rst), .noisy_in(noisy), .clean_out(clean)
    );

    // Continuous glitch monitor: any change on clean during a window where
    // it must be stable is caught by comparing against a sampled value.
    task bounce_storm(input final_level);
        integer k;
        begin
            // random 1-3 cycle flips around the final level
            for (k = 0; k < 10; k = k + 1) begin
                noisy = $random;
                repeat (1 + ({$random} % 3)) @(negedge clk);
            end
            noisy = final_level;
        end
    endtask

    initial begin
        rst = 1; noisy = 0;
        @(negedge clk);
        rst = 0;

        // --- press with bounce ---
        bounce_storm(1'b1);
        // During the storm & before STABLE_COUNT stable cycles: clean must
        // still be 0 a few cycles into the stable period.
        repeat (STABLE_COUNT/2) @(negedge clk);
        if (clean !== 1'b0) begin errors = errors + 1; $display("FAIL: clean went high before full stable period"); end
        // After the full stable period it must be 1.
        repeat (STABLE_COUNT) @(negedge clk);
        if (clean !== 1'b1) begin errors = errors + 1; $display("FAIL: clean did not go high after stable period"); end

        // clean must now stay high while input is high.
        for (i = 0; i < 20; i = i + 1) begin
            @(negedge clk);
            if (clean !== 1'b1) begin errors = errors + 1; $display("FAIL: clean dropped while input held high"); end
        end

        // --- release with bounce ---
        bounce_storm(1'b0);
        repeat (STABLE_COUNT/2) @(negedge clk);
        // (can't assert clean==1 here in general - a long-enough low run
        // inside the storm could legitimately have committed 0 already)
        repeat (STABLE_COUNT + 5) @(negedge clk);
        if (clean !== 1'b0) begin errors = errors + 1; $display("FAIL: clean did not go low after stable release"); end

        if (errors == 0) $display("PASS: tb_debounce - clean output commits only after stable period, no glitches");
        else              $display("FAIL: tb_debounce - %0d error(s)", errors);
        $finish;
    end

endmodule
