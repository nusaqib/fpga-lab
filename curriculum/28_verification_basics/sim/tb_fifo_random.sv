`timescale 1ns / 1ps

// Constrained-random verification with a scoreboard - the methodology
// upgrade, demonstrated by catching what tb_fifo_directed provably
// can't. Both FIFOs get the same 20,000 cycles of bursty random
// traffic; an SV queue plays the golden reference. Verdict:
//
//   correct FIFO: zero mismatches            (else FAIL)
//   buggy FIFO:   mismatch MUST be found     (else FAIL - the whole
//                 point is that randomness reaches where directed
//                 tests don't)
//
// Plus the other two legs of the stool:
//  - concurrent assertions (SVA) on structural invariants,
//  - functional coverage, hand-rolled as counters: coverage is just
//    "which interesting situations actually happened", and counting
//    them yourself once removes all the mystery from covergroups.
module tb_fifo_random;

    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;

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

    // ---------------- golden models: SV queues ----------------
    byte g_model[$], b_model[$];
    integer g_mismatch = 0, b_mismatch = 0;
    integer b_first_fail = -1;

    // ---------------- functional coverage, demystified ----------------
    integer cov_level[0:8];          // occupancy histogram
    initial for (int k = 0; k <= 8; k++) cov_level[k] = 0;
    // ^ uninitialized integers are X, and X+1 is X: the histogram would
    //   print x forever AND the ==0 hole check would never fire (x != 0).
    //   A coverage bug hiding a coverage hole - very on-theme.
    integer cov_push_pop  = 0;       // simultaneous push+pop
    integer cov_push_full = 0;       // push attempted while full
    integer cov_pop_empty = 0;       // pop attempted while empty
    integer cov_b2b_full  = 0;       // back-to-back pushes at the boundary
    integer ops = 0;
    reg prev_push = 0;

    // ---------------- assertions on the CORRECT design ----------------
    // structural invariants that must hold no matter the stimulus
    property p_count_sane;
        @(posedge clk) disable iff (rst) g_count <= 4'd8;
    endproperty
    a_count_sane: assert property (p_count_sane)
        else $error("SVA: count exceeded depth");

    property p_flags_consistent;
        @(posedge clk) disable iff (rst) !(g_full && g_empty);
    endproperty
    a_flags: assert property (p_flags_consistent)
        else $error("SVA: full and empty simultaneously");

    property p_empty_matches_count;
        @(posedge clk) disable iff (rst) g_empty == (g_count == 0);
    endproperty
    a_empty: assert property (p_empty_matches_count)
        else $error("SVA: empty flag disagrees with count");

    // ---------------- stimulus + scoreboard ----------------
    integer burst = 0;
    integer i;

    always @(negedge clk) if (!rst) begin
        // bursty pushes: hold push high for whole bursts so back-to-back
        // full-boundary pushes actually occur (the corner that matters)
        if (burst == 0 && ($urandom_range(0, 9) < 3))
            burst = $urandom_range(2, 12);
        if (burst > 0) begin
            push  = 1;
            wdata = $urandom;
            burst = burst - 1;
        end else
            push = 0;
        pop = ($urandom_range(0, 9) < 4);
    end

    always @(posedge clk) if (!rst) begin
        ops <= ops + 1;

        // coverage sampling
        cov_level[g_count] <= cov_level[g_count] + 1;
        if (push && pop)              cov_push_pop  <= cov_push_pop + 1;
        if (push && g_full)           cov_push_full <= cov_push_full + 1;
        if (pop  && g_empty)          cov_pop_empty <= cov_pop_empty + 1;
        if (push && prev_push && g_count >= 4'd7)
                                      cov_b2b_full  <= cov_b2b_full + 1;
        prev_push <= push;

        // scoreboard: model exactly what each DUT CLAIMS to accept
        if (pop && !g_empty) begin
            if (g_model.size() == 0 || g_rdata !== g_model[0])
                g_mismatch <= g_mismatch + 1;
            if (g_model.size() != 0) void'(g_model.pop_front());
        end
        if (push && !g_full)
            g_model.push_back(wdata);

        if (pop && !b_empty) begin
            if (b_model.size() == 0 || b_rdata !== b_model[0]) begin
                if (b_first_fail < 0) b_first_fail = ops;
                b_mismatch <= b_mismatch + 1;
            end
            if (b_model.size() != 0) void'(b_model.pop_front());
        end
        if (push && !b_full)
            b_model.push_back(wdata);
    end

    initial begin
        repeat (4) @(negedge clk);
        rst = 0;

        repeat (20000) @(posedge clk);

        $display("--- coverage (correct FIFO) after %0d cycles ---", ops);
        for (i = 0; i <= 8; i = i + 1)
            $display("  occupancy %0d: %0d cycles", i, cov_level[i]);
        $display("  push+pop same cycle: %0d", cov_push_pop);
        $display("  push while full:     %0d", cov_push_full);
        $display("  pop while empty:     %0d", cov_pop_empty);
        $display("  b2b push at boundary:%0d", cov_b2b_full);

        begin : verdict
            integer holes;
            holes = 0;
            for (i = 0; i <= 8; i = i + 1)
                if (cov_level[i] == 0) holes = holes + 1;
            if (cov_push_pop == 0 || cov_push_full == 0 ||
                cov_pop_empty == 0 || cov_b2b_full == 0) holes = holes + 1;

            $display("correct FIFO mismatches: %0d", g_mismatch);
            if (b_first_fail >= 0)
                $display("BUGGY FIFO caught: first corruption at cycle %0d (%0d total)",
                         b_first_fail, b_mismatch);
            else
                $display("BUGGY FIFO not caught!");

            if (g_mismatch == 0 && b_first_fail >= 0 && holes == 0)
                $display("PASS: correct design clean, planted bug found, all coverage bins hit");
            else if (holes != 0)
                $display("FAIL: coverage holes - stimulus never reached %0d bin(s)", holes);
            else if (g_mismatch != 0)
                $display("FAIL: correct FIFO corrupted data");
            else
                $display("FAIL: random stimulus missed the planted bug");
        end
        $finish;
    end

endmodule
