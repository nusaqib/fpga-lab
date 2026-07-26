`timescale 1ns / 1ps

// The whole RTL pipeline (src -> scaler) with the bench playing the part
// of a HOSTILE downstream: TREADY toggles randomly every cycle. A queue
// model predicts every output beat (input sequence x SCALE, TLAST every
// BEATS-th beat). This is the test that catches skid-buffer bugs - a
// dropped or duplicated beat under backpressure shifts the whole sequence
// and fails loudly. Also checks the AXI-Stream stability rule: while
// TVALID is high and TREADY low, TDATA/TLAST must not change.
module tb_axis_pipeline;

    localparam WIDTH = 32, BEATS = 16, SCALE = 3;
    localparam PACKETS = 30;

    reg clk = 0, rstn;
    always #5 clk = ~clk;

    reg  start = 0;
    wire [WIDTH-1:0] src_data,  out_data;
    wire             src_valid, src_last, src_ready;
    wire             out_valid, out_last;
    reg              out_ready = 0;
    wire [WIDTH-1:0] total_count;

    axis_counter_src #(.WIDTH(WIDTH), .BEATS(BEATS)) u_src (
        .aclk(clk), .aresetn(rstn), .start(start),
        .m_axis_tdata(src_data), .m_axis_tvalid(src_valid),
        .m_axis_tlast(src_last), .m_axis_tready(src_ready),
        .total_count(total_count)
    );

    axis_scaler #(.WIDTH(WIDTH), .SCALE(SCALE)) u_scl (
        .aclk(clk), .aresetn(rstn),
        .s_axis_tdata(src_data), .s_axis_tvalid(src_valid),
        .s_axis_tlast(src_last), .s_axis_tready(src_ready),
        .m_axis_tdata(out_data), .m_axis_tvalid(out_valid),
        .m_axis_tlast(out_last), .m_axis_tready(out_ready)
    );

    integer errors = 0;
    integer beats_seen = 0;
    integer expected_total = PACKETS * BEATS;
    reg [WIDTH-1:0] expect_data = 0;
    reg [WIDTH-1:0] hold_data;
    reg             hold_last, was_stalled = 0;

    // scoreboard + protocol monitor, sampled on the clock like hardware
    always @(posedge clk) begin
        if (rstn) begin
            // stability rule: a stalled beat must hold still
            if (was_stalled && out_valid) begin
                if (out_data !== hold_data || out_last !== hold_last) begin
                    errors = errors + 1;
                    $display("FAIL stability: beat changed while stalled (%h->%h)", hold_data, out_data);
                end
            end
            was_stalled <= out_valid && !out_ready;
            if (out_valid && !out_ready) begin
                hold_data <= out_data;
                hold_last <= out_last;
            end
            // accepted beat: check value and TLAST position
            if (out_valid && out_ready) begin
                if (out_data !== expect_data * SCALE) begin
                    errors = errors + 1;
                    $display("FAIL beat %0d: data=%0d exp=%0d", beats_seen, out_data, expect_data * SCALE);
                end
                if (out_last !== ((expect_data % BEATS) == BEATS-1)) begin
                    errors = errors + 1;
                    $display("FAIL beat %0d: tlast=%b misplaced", beats_seen, out_last);
                end
                expect_data <= expect_data + 1;
                beats_seen  <= beats_seen + 1;
            end
        end
    end

    // hostile downstream: random TREADY
    always @(negedge clk)
        out_ready = $random;

    integer p;
    initial begin
        rstn = 0;
        repeat (4) @(negedge clk);
        rstn = 1;
        repeat (2) @(negedge clk);

        for (p = 0; p < PACKETS; p = p + 1) begin
            start = 1;
            @(negedge clk);
            start = 0;
            // wait for the source to finish its packet before restarting
            wait (u_src.busy === 1'b0);
            @(negedge clk);
        end

        // drain
        repeat (100) @(negedge clk);
        if (beats_seen !== expected_total) begin
            errors = errors + 1;
            $display("FAIL: %0d beats arrived, expected %0d", beats_seen, expected_total);
        end

        if (errors == 0) $display("PASS: tb_axis_pipeline - %0d packets x %0d beats through the skid buffer under random backpressure", PACKETS, BEATS);
        else              $display("FAIL: tb_axis_pipeline - %0d error(s)", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL: tb_axis_pipeline - watchdog timeout (beats_seen=%0d)", beats_seen);
        $finish;
    end

endmodule
