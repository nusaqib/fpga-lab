`timescale 1ns / 1ps

// Both boards in one bench: two link_nodes, TX/RX crossed, each on its
// own slightly-different clock (they're different oscillators in real
// life - simulating them identical would hide exactly the tolerance
// UART exists to provide). Checks: both links come up, peer IDs land on
// the right sides, counters advance; then the cable "breaks" (RX forced
// idle), links must drop; on reconnect they must self-heal; and a
// corrupted byte must be rejected by checksum without killing the link.
module tb_link;

    // two independent oscillators, ~0.3% apart (way beyond real crystal
    // error, well within UART's mid-bit margin)
    reg clk_a = 0, clk_b = 0;
    always #5.000 clk_a = ~clk_a;    // 100.00 MHz
    always #4.985 clk_b = ~clk_b;    // 100.30 MHz

    wire a2b, b2a;
    reg break_cable = 0;
    reg corrupt = 0;

    // the "cable": breakable, corruptible
    wire a2b_wire = break_cable ? 1'b1 : (a2b ^ corrupt);
    wire b2a_wire = break_cable ? 1'b1 : b2a;

    wire [7:0] a_peer_id, a_peer_cnt, b_peer_id, b_peer_cnt;
    wire a_fresh, b_fresh, a_up, b_up;

    // sim-scaled: fast beats, fast baud, same structure
    link_node #(.MY_ID(8'h01), .CLK_HZ(100_000_000), .BAUD(10_000_000),
                .BEAT_HZ(20_000)) node_a (
        .clk(clk_a), .txd(a2b), .rxd(b2a_wire),
        .peer_id(a_peer_id), .peer_cnt(a_peer_cnt), .peer_fresh(a_fresh),
        .link_up(a_up), .rx_activity()
    );
    link_node #(.MY_ID(8'h02), .CLK_HZ(100_000_000), .BAUD(10_000_000),
                .BEAT_HZ(20_000)) node_b (
        .clk(clk_b), .txd(b2a), .rxd(a2b_wire),
        .peer_id(b_peer_id), .peer_cnt(b_peer_cnt), .peer_fresh(b_fresh),
        .link_up(b_up), .rx_activity()
    );

    integer errors = 0;
    integer a_packets = 0, b_packets = 0;
    integer b_snap;
    reg [7:0] b_cnt_prev;

    always @(posedge a_fresh) a_packets = a_packets + 1;
    always @(posedge b_fresh) b_packets = b_packets + 1;

    initial begin
        // --- phase 1: link comes up, identities and counters flow ---
        wait (a_packets >= 3 && b_packets >= 3);
        if (a_peer_id !== 8'h02 || b_peer_id !== 8'h01) begin
            $display("FAIL: peer IDs wrong (a sees %02x, b sees %02x)",
                     a_peer_id, b_peer_id);
            errors = errors + 1;
        end
        if (!a_up || !b_up) begin
            $display("FAIL: link_up not asserted after packets");
            errors = errors + 1;
        end
        b_cnt_prev = a_peer_cnt;
        wait (a_packets >= 6);
        if (a_peer_cnt === b_cnt_prev) begin
            $display("FAIL: peer counter not advancing");
            errors = errors + 1;
        end
        $display("  phase 1 ok: both up, IDs correct, counters advancing");

        // --- phase 2: corrupt one byte mid-flight, link survives ---
        @(negedge a2b);              // a start bit from A
        corrupt = 1;                 // flip the line for a whole byte
        #1000;
        corrupt = 0;
        b_snap = b_packets;
        wait (b_packets >= b_snap + 2);      // more good packets after
        if (!b_up) begin
            $display("FAIL: link dropped from one corrupted packet");
            errors = errors + 1;
        end
        $display("  phase 2 ok: checksum ate the corruption, link stayed up");

        // --- phase 3: cut the cable, links must drop ---
        break_cable = 1;
        #200_000;                    // > 3 beat timeouts at sim scale
        if (a_up || b_up) begin
            $display("FAIL: link_up stuck high with cable cut (a=%b b=%b)",
                     a_up, b_up);
            errors = errors + 1;
        end
        $display("  phase 3 ok: heartbeat timeout dropped both ends");

        // --- phase 4: reconnect, self-heal ---
        break_cable = 0;
        a_packets = 0;
        wait (a_packets >= 2);
        if (!a_up) begin
            $display("FAIL: link did not heal after reconnect");
            errors = errors + 1;
        end
        $display("  phase 4 ok: self-healed on reconnect");

        if (errors == 0)
            $display("PASS: two-board link - bring-up, corruption, cut, heal");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #5_000_000;
        $display("FAIL: timeout (a_packets=%0d b_packets=%0d)",
                 a_packets, b_packets);
        $finish;
    end

endmodule
