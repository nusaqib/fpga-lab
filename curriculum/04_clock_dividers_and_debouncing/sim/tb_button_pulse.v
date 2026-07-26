`timescale 1ns / 1ps

// The argument for the debouncer, in executable form. Two counting paths
// fed by the SAME bouncy press:
//
//   path A (naive):   sync2 -> edge_detect -> count
//   path B (correct): sync2 -> debounce -> edge_detect -> count
//
// After 5 bouncy presses, path B must have counted exactly 5. Path A will
// have counted more (one per bounce) - the bench asserts it OVERCOUNTS,
// because that's the point: if the naive path happened to count 5 too, the
// bounce model wasn't bouncy enough to prove anything.
module tb_button_pulse;

    localparam STABLE_COUNT = 20;
    localparam PRESSES = 5;

    reg  clk = 0, rst, btn;
    integer errors = 0;
    integer p;

    always #5 clk = ~clk;

    // path A: naive
    wire btn_s, pulse_naive;
    reg [7:0] count_naive = 0;
    sync2       uA_sync (.clk(clk), .async_in(btn), .sync_out(btn_s));
    edge_detect uA_edge (.clk(clk), .level_in(btn_s), .pulse_out(pulse_naive));
    always @(posedge clk) if (pulse_naive) count_naive <= count_naive + 1;

    // path B: debounced
    wire btn_clean, pulse_clean;
    reg [7:0] count_clean = 0;
    debounce #(.STABLE_COUNT(STABLE_COUNT)) uB_db (.clk(clk), .rst(rst), .noisy_in(btn), .clean_out(btn_clean));
    edge_detect uB_edge (.clk(clk), .level_in(btn_clean), .pulse_out(pulse_clean));
    always @(posedge clk) if (pulse_clean) count_clean <= count_clean + 1;

    // A press whose leading AND trailing edges both bounce hard, with
    // enough guaranteed-high time in the middle for the debouncer to
    // commit, and guaranteed-low time after for the release to commit.
    task bouncy_press;
        integer k;
        begin
            for (k = 0; k < 6; k = k + 1) begin   // leading bounce
                btn = ~btn;
                repeat (1 + ({$random} % 2)) @(negedge clk);
            end
            btn = 1;
            repeat (STABLE_COUNT * 2) @(negedge clk);   // held
            for (k = 0; k < 6; k = k + 1) begin   // trailing bounce
                btn = ~btn;
                repeat (1 + ({$random} % 2)) @(negedge clk);
            end
            btn = 0;
            repeat (STABLE_COUNT * 2) @(negedge clk);   // released
        end
    endtask

    initial begin
        rst = 1; btn = 0;
        @(negedge clk);
        rst = 0;
        repeat (4) @(negedge clk);

        for (p = 0; p < PRESSES; p = p + 1)
            bouncy_press;

        $display("INFO: naive path counted %0d, debounced path counted %0d, real presses = %0d",
                 count_naive, count_clean, PRESSES);

        if (count_clean !== PRESSES[7:0]) begin
            errors = errors + 1;
            $display("FAIL: debounced path counted %0d, expected exactly %0d", count_clean, PRESSES);
        end
        if (count_naive <= PRESSES[7:0]) begin
            errors = errors + 1;
            $display("FAIL: naive path counted %0d - bounce model too tame to demonstrate the problem", count_naive);
        end

        if (errors == 0) $display("PASS: tb_button_pulse - debounced=exactly %0d, naive overcounted (%0d)", PRESSES, count_naive);
        else              $display("FAIL: tb_button_pulse - %0d error(s)", errors);
        $finish;
    end

endmodule
