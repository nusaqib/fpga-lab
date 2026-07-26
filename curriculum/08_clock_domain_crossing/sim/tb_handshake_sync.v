`timescale 1ns / 1ps

// Sends a known sequence of words fast->slow and slow->fast (two DUTs);
// every word must arrive exactly once, in order, with the right value -
// the source obeying src_busy is the only flow control there is.
module tb_handshake_sync;

    localparam WIDTH = 8;
    localparam WORDS = 40;

    reg clk_a = 0, clk_b = 0;
    always #3.5  clk_a = ~clk_a;
    always #5.65 clk_b = ~clk_b;

    // ---- a -> b ----
    reg              va = 0;
    reg  [WIDTH-1:0] da;
    wire             busy_a, vb;
    wire [WIDTH-1:0] db;
    integer got_ab = 0, errors = 0;
    integer i;

    handshake_sync #(.WIDTH(WIDTH)) u_a2b (
        .src_clk(clk_a), .src_valid(va), .src_data(da), .src_busy(busy_a),
        .dst_clk(clk_b), .dst_valid(vb), .dst_data(db)
    );

    always @(posedge clk_b) begin
        if (vb) begin
            if (db !== got_ab[WIDTH-1:0] + 8'h10) begin
                errors = errors + 1;
                $display("FAIL a->b word %0d: got %h exp %h", got_ab, db, got_ab[WIDTH-1:0] + 8'h10);
            end
            got_ab = got_ab + 1;
        end
    end

    // ---- b -> a ----
    reg              vb2 = 0;
    reg  [WIDTH-1:0] db2;
    wire             busy_b, va2;
    wire [WIDTH-1:0] da2;
    integer got_ba = 0;

    handshake_sync #(.WIDTH(WIDTH)) u_b2a (
        .src_clk(clk_b), .src_valid(vb2), .src_data(db2), .src_busy(busy_b),
        .dst_clk(clk_a), .dst_valid(va2), .dst_data(da2)
    );

    always @(posedge clk_a) begin
        if (va2) begin
            if (da2 !== got_ba[WIDTH-1:0] + 8'hA0) begin
                errors = errors + 1;
                $display("FAIL b->a word %0d: got %h exp %h", got_ba, da2, got_ba[WIDTH-1:0] + 8'hA0);
            end
            got_ba = got_ba + 1;
        end
    end

    initial begin
        da = 0; db2 = 0;
        @(negedge clk_a);

        // a -> b: send WORDS values, waiting out src_busy each time
        for (i = 0; i < WORDS; i = i + 1) begin
            while (busy_a) @(negedge clk_a);
            da = i[WIDTH-1:0] + 8'h10;
            va = 1;
            @(negedge clk_a);
            va = 0;
        end

        // b -> a: same, other direction
        for (i = 0; i < WORDS; i = i + 1) begin
            while (busy_b) @(negedge clk_b);
            db2 = i[WIDTH-1:0] + 8'hA0;
            vb2 = 1;
            @(negedge clk_b);
            vb2 = 0;
        end

        // drain
        repeat (40) @(negedge clk_b);

        if (got_ab !== WORDS) begin
            errors = errors + 1;
            $display("FAIL a->b: %0d of %0d words arrived", got_ab, WORDS);
        end
        if (got_ba !== WORDS) begin
            errors = errors + 1;
            $display("FAIL b->a: %0d of %0d words arrived", got_ba, WORDS);
        end

        if (errors == 0) $display("PASS: tb_handshake_sync - %0d words each way, in order, none lost/dup'd", WORDS);
        else              $display("FAIL: tb_handshake_sync - %0d error(s)", errors);
        $finish;
    end

endmodule
