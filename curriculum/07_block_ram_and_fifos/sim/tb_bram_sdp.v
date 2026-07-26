`timescale 1ns / 1ps

// Reference-model bench for the SDP RAM: a plain array shadow-copies every
// write, random reads are checked one cycle later (read latency 1), and a
// directed collision test pins down the cross-port semantics (read of the
// address being written returns OLD data).
module tb_bram_sdp;

    localparam WIDTH = 8, DEPTH = 64;   // small depth: fills fast in sim
    localparam AW = $clog2(DEPTH);
    localparam CYCLES = 1000;

    reg               clk = 0;
    reg               we, re;
    reg  [AW-1:0]     waddr, raddr;
    reg  [WIDTH-1:0]  wdata;
    wire [WIDTH-1:0]  rdata;

    reg [WIDTH-1:0] shadow [0:DEPTH-1];
    reg [WIDTH-1:0] expected;
    reg             check_pending;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    bram_sdp #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (
        .clk(clk), .we(we), .waddr(waddr), .wdata(wdata),
        .re(re), .raddr(raddr), .rdata(rdata)
    );

    initial begin
        we = 0; re = 0; check_pending = 0;

        // Fill every location once so shadow and DUT agree everywhere.
        for (i = 0; i < DEPTH; i = i + 1) begin
            @(negedge clk);
            we = 1; waddr = i[AW-1:0]; wdata = i[WIDTH-1:0] ^ 8'hA5;
            shadow[i] = i[WIDTH-1:0] ^ 8'hA5;
        end
        @(negedge clk);
        we = 0;

        // Random reads and writes; check each read one cycle later.
        for (i = 0; i < CYCLES; i = i + 1) begin
            @(negedge clk);
            // check the read issued LAST cycle
            if (check_pending && rdata !== expected) begin
                errors = errors + 1;
                $display("FAIL read %0d: rdata=%h exp=%h", i, rdata, expected);
            end
            // new random operations
            we    = $random;
            waddr = $random;
            wdata = $random;
            re    = 1;
            raddr = $random;
            // shadow: capture expected BEFORE the write lands (read-first
            // collision semantics fall out naturally from ordering here)
            expected      = shadow[raddr];
            check_pending = 1;
            if (we) shadow[waddr] = wdata;
        end
        @(negedge clk);
        we = 0; re = 0;

        // Directed collision: write X to addr 5 while reading addr 5.
        @(negedge clk);
        we = 1; waddr = 5; wdata = 8'h3C;
        re = 1; raddr = 5;
        expected = shadow[5];            // OLD data must come out
        @(negedge clk);
        we = 0; re = 0;
        if (rdata !== expected) begin
            errors = errors + 1;
            $display("FAIL collision: rdata=%h exp OLD=%h", rdata, expected);
        end
        // and one cycle later a re-read returns the NEW data
        @(negedge clk);
        re = 1; raddr = 5;
        @(negedge clk);
        re = 0;
        if (rdata !== 8'h3C) begin
            errors = errors + 1;
            $display("FAIL post-collision: rdata=%h exp NEW=3c", rdata);
        end

        if (errors == 0) $display("PASS: tb_bram_sdp - %0d random ops + read-first collision semantics", CYCLES);
        else              $display("FAIL: tb_bram_sdp - %0d error(s)", errors);
        $finish;
    end

endmodule
