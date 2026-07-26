`timescale 1ns / 1ps

// Two genuinely unrelated clocks (7ns and 11.3ns periods - no common
// multiple within the sim), pulses fired both fast->slow and slow->fast
// (two DUT instances), spaced to respect the toggle-propagation rule.
// Every source pulse must produce exactly one destination pulse.
module tb_pulse_sync;

    localparam PULSES = 50;

    reg clk_a = 0, clk_b = 0;
    always #3.5  clk_a = ~clk_a;    // 7ns period
    always #5.65 clk_b = ~clk_b;    // 11.3ns period

    reg  pulse_a = 0, pulse_b = 0;
    wire pulse_a2b, pulse_b2a;
    integer sent_ab = 0, got_ab = 0, sent_ba = 0, got_ba = 0;
    integer errors = 0;
    integer i;

    pulse_sync u_a2b (.src_clk(clk_a), .src_pulse(pulse_a), .dst_clk(clk_b), .dst_pulse(pulse_a2b));
    pulse_sync u_b2a (.src_clk(clk_b), .src_pulse(pulse_b), .dst_clk(clk_a), .dst_pulse(pulse_b2a));

    always @(posedge clk_b) if (pulse_a2b) got_ab = got_ab + 1;
    always @(posedge clk_a) if (pulse_b2a) got_ba = got_ba + 1;

    initial begin
        // fast -> slow
        for (i = 0; i < PULSES; i = i + 1) begin
            @(negedge clk_a);
            pulse_a = 1;
            @(negedge clk_a);
            pulse_a = 0;
            sent_ab = sent_ab + 1;
            repeat (8) @(negedge clk_a);   // >> 3 dst (clk_b) cycles
        end
        // slow -> fast
        for (i = 0; i < PULSES; i = i + 1) begin
            @(negedge clk_b);
            pulse_b = 1;
            @(negedge clk_b);
            pulse_b = 0;
            sent_ba = sent_ba + 1;
            repeat (4) @(negedge clk_b);
        end
        // drain
        repeat (20) @(negedge clk_b);

        if (got_ab !== sent_ab) begin
            errors = errors + 1;
            $display("FAIL a->b: sent %0d pulses, received %0d", sent_ab, got_ab);
        end
        if (got_ba !== sent_ba) begin
            errors = errors + 1;
            $display("FAIL b->a: sent %0d pulses, received %0d", sent_ba, got_ba);
        end

        if (errors == 0) $display("PASS: tb_pulse_sync - %0d pulses each way across unrelated clocks, none lost or duplicated", PULSES);
        else              $display("FAIL: tb_pulse_sync - %0d error(s)", errors);
        $finish;
    end

endmodule
