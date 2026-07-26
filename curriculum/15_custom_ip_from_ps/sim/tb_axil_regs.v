`timescale 1ns / 1ps

// Bench with a minimal AXI4-Lite master implemented as tasks - the same
// role a VIP (verification IP) plays in grown-up environments. Covers:
// scratch write/readback, LED register driving the led pins, STATUS
// reflecting sw/btn inputs, the ID constant, byte strobes (partial
// writes), SLVERR on out-of-range and read-only addresses, and a stall
// test (master delays wdata and bready - the slave must wait politely).
module tb_axil_regs;

    reg         aclk = 0;
    reg         aresetn;
    always #5 aclk = ~aclk;

    // AXI-Lite wires
    reg  [31:0] awaddr;  reg awvalid;  wire awready;
    reg  [31:0] wdata;   reg [3:0] wstrb; reg wvalid; wire wready;
    wire [1:0]  bresp;   wire bvalid;  reg bready;
    reg  [31:0] araddr;  reg arvalid;  wire arready;
    wire [31:0] rdata;   wire [1:0] rresp; wire rvalid; reg rready;

    wire [3:0] led;
    reg  [3:0] sw;
    reg        btn;

    integer errors = 0;
    reg [31:0] rd_val;
    reg [1:0]  rd_resp, wr_resp;

    axil_regs dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
        .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
        .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
        .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
        .led(led), .sw(sw), .btn(btn)
    );

    // ---- master tasks ----
    // Handshake-sampling subtlety these tasks encode: a transfer happens
    // at the posedge where valid AND ready are both high GOING IN. Driving
    // and observing from negedges, the ready that matters is the one
    // visible at the negedge BEFORE the posedge - sample it, cross the
    // edge, then decide. (Checking ready after the edge misses accepts,
    // because this slave drops ready the same edge it captures - the
    // first version of this bench hung exactly that way.)
    reg r_aw, r_w, r_ar;

    task axi_write(input [31:0] addr, input [31:0] data, input [3:0] strb,
                   input integer w_delay, input integer b_delay);
        begin
            @(negedge aclk);
            // AW and W are INDEPENDENT channels - each needs its own
            // watcher, because AW can be accepted while W is still being
            // deliberately delayed (a single sequential wait-for-both
            // loop missed exactly that and hung this bench's stall test).
            fork
                begin : aw_thread
                    awaddr = addr; awvalid = 1;
                    while (awvalid) begin
                        r_aw = awready;
                        @(negedge aclk);
                        if (r_aw) awvalid = 0;
                    end
                end
                begin : w_thread
                    repeat (w_delay) @(negedge aclk);
                    wdata = data; wstrb = strb; wvalid = 1;
                    while (wvalid) begin
                        r_w = wready;
                        @(negedge aclk);
                        if (r_w) wvalid = 0;
                    end
                end
            join
            // response, optionally stalled by the master
            repeat (b_delay) @(negedge aclk);
            bready = 1;
            while (!bvalid) @(negedge aclk);
            wr_resp = bresp;
            @(negedge aclk);   // cross the accepting edge
            bready = 0;
        end
    endtask

    task axi_read(input [31:0] addr, input integer r_delay);
        begin
            @(negedge aclk);
            araddr = addr; arvalid = 1;
            while (arvalid) begin
                r_ar = arready;
                @(negedge aclk);
                if (r_ar && arvalid) arvalid = 0;
            end
            repeat (r_delay) @(negedge aclk);
            rready = 1;
            while (!rvalid) @(negedge aclk);
            rd_val  = rdata;
            rd_resp = rresp;
            @(negedge aclk);   // cross the accepting edge
            rready = 0;
        end
    endtask

    task check(input cond, input [255:0] label);
        if (!cond) begin
            errors = errors + 1;
            $display("FAIL %0s (rd_val=%h rd_resp=%b wr_resp=%b)", label, rd_val, rd_resp, wr_resp);
        end
    endtask

    initial begin
        awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;
        awaddr = 0; wdata = 0; wstrb = 0; araddr = 0;
        sw = 4'b1010; btn = 0;
        aresetn = 0;
        repeat (4) @(negedge aclk);
        aresetn = 1;
        repeat (2) @(negedge aclk);

        // ID register
        axi_read(32'h0C, 0);
        check(rd_val === 32'hF19A_1AB0 && rd_resp === 2'b00, "ID readback");

        // scratch write + readback
        axi_write(32'h00, 32'hCAFE_F00D, 4'hF, 0, 0);
        check(wr_resp === 2'b00, "scratch write OKAY");
        axi_read(32'h00, 0);
        check(rd_val === 32'hCAFE_F00D, "scratch readback");

        // byte strobes: overwrite only byte 1 (CAFE_F00D -> CAFE_550D)
        axi_write(32'h00, 32'h0000_5500, 4'b0010, 0, 0);
        axi_read(32'h00, 0);
        check(rd_val === 32'hCAFE_550D, "byte-strobe partial write");

        // LED register drives pins
        axi_write(32'h04, 32'h0000_0009, 4'hF, 0, 0);
        repeat (2) @(negedge aclk);
        check(led === 4'b1001, "LED pins follow LED register");

        // STATUS reflects inputs
        sw = 4'b0110; btn = 1;
        repeat (2) @(negedge aclk);
        axi_read(32'h08, 0);
        check(rd_val[3:0] === 4'b0110 && rd_val[8] === 1'b1, "STATUS reflects sw/btn");

        // stall torture: delayed W by 3, delayed B accept by 4
        axi_write(32'h00, 32'h1111_2222, 4'hF, 3, 4);
        axi_read(32'h00, 2);
        check(rd_val === 32'h1111_2222, "write with stalled W/B channels");

        // out-of-range read -> SLVERR
        axi_read(32'h40, 0);
        check(rd_resp === 2'b10, "out-of-range read SLVERR");

        // write to RO STATUS -> SLVERR, value unaffected
        axi_write(32'h08, 32'hFFFF_FFFF, 4'hF, 0, 0);
        check(wr_resp === 2'b10, "RO write SLVERR");
        axi_read(32'h08, 0);
        check(rd_val[3:0] === 4'b0110, "RO register unmodified");

        if (errors == 0) $display("PASS: tb_axil_regs - full register map, strobes, stalls, and error responses");
        else              $display("FAIL: tb_axil_regs - %0d error(s)", errors);
        $finish;
    end

    // Watchdog: a handshake bench must fail loudly, never hang (a stuck
    // valid/ready loop is itself a bug report - see the task comments).
    initial begin
        #100_000;
        $display("FAIL: tb_axil_regs - watchdog timeout (a handshake never completed)");
        $finish;
    end

endmodule
