`timescale 1ns / 1ps

// tb_axis_snap (module 22) adapted to the 256-bit I/Q recorder: sixteen
// incrementing 16-bit lanes per beat, consecutive-sample check across the
// full buffer plus the same protocol checks (ID, DEPTH, SLVERR, re-arm).
module tb_axis_snap_iq;

    reg aclk = 0;
    always #1.628 aclk = ~aclk;
    reg aresetn = 0;

    reg  [31:0] awaddr = 0;  reg awvalid = 0;  wire awready;
    reg  [31:0] wdata = 0;   reg [3:0] wstrb = 4'hF; reg wvalid = 0; wire wready;
    wire [1:0]  bresp;       wire bvalid;      reg bready = 1;
    reg  [31:0] araddr = 0;  reg arvalid = 0;  wire arready;
    wire [31:0] rdata;       wire [1:0] rresp; wire rvalid; reg rready = 1;

    reg [15:0] beat_base = 16'h2000;
    genvar g;
    wire [255:0] tdata;
    generate
        for (g = 0; g < 16; g = g + 1)
            assign tdata[g*16 +: 16] = beat_base + g[15:0];
    endgenerate
    wire tvalid = aresetn;
    wire tready;
    always @(posedge aclk)
        if (aresetn && tvalid && tready) beat_base <= beat_base + 16'd16;

    axis_snap_iq #(.DEPTH_LOG2(4)) dut (
        .aclk(aclk), .aresetn(aresetn),
        .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
        .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
        .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
        .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
        .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
        .s_axis_tdata(tdata), .s_axis_tvalid(tvalid), .s_axis_tready(tready)
    );

    integer errors = 0;

    task axil_write(input [31:0] a, input [31:0] d, input [1:0] exp_resp);
        begin
            @(posedge aclk);
            awaddr <= a; awvalid <= 1; wdata <= d; wvalid <= 1;
            fork
                begin : waw
                    while (!(awvalid && awready)) @(posedge aclk);
                    awvalid <= 0;
                end
                begin : ww
                    while (!(wvalid && wready)) @(posedge aclk);
                    wvalid <= 0;
                end
            join
            while (!bvalid) @(posedge aclk);
            if (bresp !== exp_resp) begin
                $display("FAIL: write 0x%08x bresp=%b expected %b", a, bresp, exp_resp);
                errors = errors + 1;
            end
            @(posedge aclk);
        end
    endtask

    task axil_read(input [31:0] a, output [31:0] d);
        begin
            @(posedge aclk);
            araddr <= a; arvalid <= 1;
            while (!(arvalid && arready)) @(posedge aclk);
            arvalid <= 0;
            while (!rvalid) @(posedge aclk);
            d = rdata;
            @(posedge aclk);
        end
    endtask

    reg [31:0] rd, status;
    reg [15:0] first_sample;
    integer b, w, i;
    reg [15:0] expect_lo, expect_hi;

    initial begin
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (5) @(posedge aclk);

        axil_read(32'h0000, rd);
        if (rd !== 32'hACE00024) begin
            $display("FAIL: ID = 0x%08x", rd); errors = errors + 1;
        end
        axil_read(32'h000C, rd);
        if (rd !== 32'd16) begin
            $display("FAIL: DEPTH = %0d", rd); errors = errors + 1;
        end
        axil_write(32'h0000, 32'hDEADBEEF, 2'b10);

        axil_write(32'h0004, 32'h1, 2'b00);
        i = 0; status = 0;
        while (status[0] !== 1'b1 && i < 1000) begin
            axil_read(32'h0008, status);
            i = i + 1;
        end
        if (status[0] !== 1'b1) begin
            $display("FAIL: capture never finished"); errors = errors + 1;
        end

        axil_read(32'h8000, rd);
        first_sample = rd[15:0];
        for (b = 0; b < 16; b = b + 1)
            for (w = 0; w < 8; w = w + 1) begin
                axil_read(32'h8000 + b*32 + w*4, rd);
                expect_lo = first_sample + b*16 + w*2;
                expect_hi = first_sample + b*16 + w*2 + 1;
                if (rd !== {expect_hi, expect_lo}) begin
                    $display("FAIL: beat %0d word %0d = 0x%08x expected 0x%04x%04x",
                             b, w, rd, expect_hi, expect_lo);
                    errors = errors + 1;
                end
            end

        axil_write(32'h0004, 32'h1, 2'b00);
        status = 0;
        while (status[0] !== 1'b1) axil_read(32'h0008, status);
        axil_read(32'h8000, rd);
        if (rd[15:0] == first_sample) begin
            $display("FAIL: re-arm captured identical data"); errors = errors + 1;
        end

        if (errors == 0) $display("PASS: axis_snap_iq all checks");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

endmodule
