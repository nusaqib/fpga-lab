`timescale 1ns / 1ps

// Both detectors, same input stream, one bench. The golden model is a
// 4-bit sliding window (`window == 1011`), which by construction handles
// overlap correctly.
//
// The Moore-vs-Mealy timing difference is captured by WHERE each check
// sits relative to the clock edge that consumes the bit:
//  - Mealy is checked BEFORE the edge (combinational on state+din: it
//    must already be asserting as the final '1' sits on the input),
//  - Moore is checked AFTER the edge (its detect state - and therefore
//    its output - only exists once the edge has moved it there).
// Same detection, one clock edge apart: that IS the one-cycle difference.
// Directed prefix "1011011" exercises overlapping matches (positions 3
// and 6) before a 500-bit random soak; the bench also requires both
// machines' total hit counts to equal the model's.
module tb_sequence_detectors;

    reg  clk = 0, rst, din;
    wire found_moore, found_mealy;
    reg  [3:0] window;
    integer errors = 0;
    integer i, mealy_hits = 0, moore_hits = 0, model_hits = 0;
    reg model_hit_now;
    reg [6:0] directed = 7'b1011011;   // fed MSB-first

    always #5 clk = ~clk;

    sequence_detector_moore u_moore (.clk(clk), .rst(rst), .din(din), .found(found_moore));
    sequence_detector_mealy u_mealy (.clk(clk), .rst(rst), .din(din), .found(found_mealy));

    task step(input bit_in);
        begin
            din = bit_in;
            window = {window[2:0], bit_in};
            model_hit_now = (window == 4'b1011);
            #1;
            // pre-edge: Mealy must be asserting NOW if this bit completes
            // the pattern.
            if (found_mealy !== model_hit_now) begin
                errors = errors + 1;
                $display("FAIL mealy @%0d: found=%b model=%b (window=%b)", i, found_mealy, model_hit_now, window);
            end
            if (found_mealy)   mealy_hits = mealy_hits + 1;
            if (model_hit_now) model_hits = model_hits + 1;
            @(negedge clk);
            // post-edge: Moore asserts only now, one cycle behind Mealy.
            if (found_moore !== model_hit_now) begin
                errors = errors + 1;
                $display("FAIL moore @%0d: found=%b model=%b", i, found_moore, model_hit_now);
            end
            if (found_moore) moore_hits = moore_hits + 1;
        end
    endtask

    initial begin
        rst = 1; din = 0; window = 0;
        @(negedge clk);
        rst = 0;

        // directed: overlapping "1011011"
        for (i = 0; i < 7; i = i + 1)
            step(directed[6-i]);

        // random soak
        for (i = 7; i < 500; i = i + 1)
            step($random);

        if (mealy_hits !== model_hits) begin
            errors = errors + 1;
            $display("FAIL: mealy_hits=%0d model_hits=%0d", mealy_hits, model_hits);
        end
        if (moore_hits !== model_hits) begin
            errors = errors + 1;
            $display("FAIL: moore_hits=%0d model_hits=%0d", moore_hits, model_hits);
        end
        if (model_hits < 10) begin
            errors = errors + 1;
            $display("FAIL: only %0d pattern occurrences - stream too tame to prove anything", model_hits);
        end

        if (errors == 0) $display("PASS: tb_sequence_detectors - %0d matches; mealy pre-edge, moore post-edge, counts agree", model_hits);
        else              $display("FAIL: tb_sequence_detectors - %0d error(s)", errors);
        $finish;
    end

endmodule
