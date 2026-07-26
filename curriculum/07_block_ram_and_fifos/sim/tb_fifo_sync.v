`timescale 1ns / 1ps

// FIFO bench with a SystemVerilog queue as the golden model - the natural
// reference for a FIFO, since a queue IS the abstract data type being
// implemented. Three phases:
//  1) directed fill-to-full / drain-to-empty, checking flags and count at
//     the boundaries and that data comes back in order,
//  2) random push/pop soak with the model queue (including deliberate
//     pushes-while-full and pops-while-empty, which must be no-ops),
//  3) final drain: everything left in the model must come out in order.
module tb_fifo_sync;

    localparam WIDTH = 8, DEPTH = 16;
    localparam SOAK = 2000;

    reg              clk = 0, rst;
    reg              wr_en, rd_en;
    reg  [WIDTH-1:0] wdata;
    wire [WIDTH-1:0] rdata;
    wire             full, empty;
    wire [$clog2(DEPTH):0] count;

    byte model[$];          // SV queue: the golden reference
    integer errors = 0;
    integer i;
    reg pop_accepted;
    byte pop_expected;

    always #5 clk = ~clk;

    fifo_sync #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .rst(rst), .wr_en(wr_en), .wdata(wdata),
        .rd_en(rd_en), .rdata(rdata), .full(full), .empty(empty), .count(count)
    );

    task do_cycle(input push_req, input [WIDTH-1:0] pdata, input pop_req);
        reg push_accepted;
        begin
            wr_en = push_req; wdata = pdata; rd_en = pop_req;
            // Model mirrors the DUT's accept conditions - BOTH evaluated
            // against the PRE-cycle occupancy. The subtle case this gets
            // right: simultaneous push+pop while full. The pop is
            // accepted, but the push is still rejected - full is computed
            // from the current pointers, not from "what the pop is about
            // to free up". (Same convention as Xilinx's FIFO cores: WR
            // while FULL is an overflow, simultaneous RD or not.)
            push_accepted = push_req && (model.size() < DEPTH);
            pop_accepted  = pop_req  && (model.size() > 0);
            if (pop_accepted)  pop_expected = model.pop_front();
            if (push_accepted) model.push_back(pdata);
            @(negedge clk);
            wr_en = 0; rd_en = 0;
            if (pop_accepted) begin
                // read latency 1: rdata valid now (one edge after accept)
                if (rdata !== pop_expected) begin
                    errors = errors + 1;
                    $display("FAIL pop: rdata=%h exp=%h", rdata, pop_expected);
                end
            end
            if (count !== model.size()) begin
                errors = errors + 1;
                $display("FAIL count: dut=%0d model=%0d", count, model.size());
            end
            if (empty !== (model.size() == 0)) begin
                errors = errors + 1;
                $display("FAIL empty flag: dut=%b model_size=%0d", empty, model.size());
            end
            if (full !== (model.size() == DEPTH)) begin
                errors = errors + 1;
                $display("FAIL full flag: dut=%b model_size=%0d", full, model.size());
            end
        end
    endtask

    initial begin
        rst = 1; wr_en = 0; rd_en = 0;
        @(negedge clk);
        rst = 0;

        // --- 1) directed fill and drain ---
        if (empty !== 1'b1) begin errors = errors + 1; $display("FAIL: not empty after reset"); end
        for (i = 0; i < DEPTH; i = i + 1)
            do_cycle(1, i[WIDTH-1:0], 0);
        if (full !== 1'b1) begin errors = errors + 1; $display("FAIL: not full after %0d pushes", DEPTH); end
        do_cycle(1, 8'hEE, 0);   // push while full: must be dropped
        for (i = 0; i < DEPTH; i = i + 1)
            do_cycle(0, 0, 1);
        if (empty !== 1'b1) begin errors = errors + 1; $display("FAIL: not empty after full drain"); end
        do_cycle(0, 0, 1);       // pop while empty: must be a no-op

        // --- 2) random soak (pushes/pops collide with flags freely) ---
        for (i = 0; i < SOAK; i = i + 1)
            do_cycle($random, $random, $random);

        // --- 3) final drain in order ---
        while (model.size() > 0)
            do_cycle(0, 0, 1);
        if (empty !== 1'b1) begin errors = errors + 1; $display("FAIL: dut not empty at end"); end

        if (errors == 0) $display("PASS: tb_fifo_sync - fill/drain boundaries + %0d-cycle random soak vs queue model", SOAK);
        else              $display("FAIL: tb_fifo_sync - %0d error(s)", errors);
        $finish;
    end

endmodule
