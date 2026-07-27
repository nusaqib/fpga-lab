`timescale 1ns / 1ps

// The system-level test: llrf_core closing a feedback loop around a
// mock cavity, all through the real register interface.
//
// Plant model (behavioral, real arithmetic): the drive IQ is rotated by
// +30 degrees and scaled by 0.5 (an "amplifier + cable + cavity coupling"
// with fixed phase and gain), then low-passed by a first-order lag
// (tau = 16 fabric cycles - a caricature cavity fill), plus a small
// static offset on I. The ADC stream carries the plant output in all
// eight beat lanes.
//
// The software procedure being emulated is the real one: set the loop
// rotation to -30 degrees to undo the plant phase, pick moderate gains,
// enable feedback, and expect MEAS to land on the setpoint - first in
// CW, then across pulses in pulsed mode. A wave_snap on the DAC stream
// re-arms from the pulse trigger, as it will in hardware.
module tb_llrf_loop;

    reg clk = 0;
    always #1.628 clk = ~clk;
    reg rstn = 0;

    // ---------------- DUT: llrf_core ----------------
    reg  [31:0] c_awaddr = 0;  reg c_awvalid = 0;  wire c_awready;
    reg  [31:0] c_wdata = 0;   reg c_wvalid = 0;   wire c_wready;
    wire [1:0]  c_bresp;       wire c_bvalid;      reg c_bready = 1;
    reg  [31:0] c_araddr = 0;  reg c_arvalid = 0;  wire c_arready;
    wire [31:0] c_rdata;       wire [1:0] c_rresp; wire c_rvalid;
    reg         c_rready = 1;

    reg  [255:0] adc_beat = 0;
    wire [255:0] dac_beat;
    wire trig_out;
    wire [3:0] led;

    llrf_core dut (
        .aclk(clk), .aresetn(rstn),
        .s_axil_awaddr(c_awaddr), .s_axil_awvalid(c_awvalid), .s_axil_awready(c_awready),
        .s_axil_wdata(c_wdata), .s_axil_wstrb(4'hF), .s_axil_wvalid(c_wvalid), .s_axil_wready(c_wready),
        .s_axil_bresp(c_bresp), .s_axil_bvalid(c_bvalid), .s_axil_bready(c_bready),
        .s_axil_araddr(c_araddr), .s_axil_arvalid(c_arvalid), .s_axil_arready(c_arready),
        .s_axil_rdata(c_rdata), .s_axil_rresp(c_rresp), .s_axil_rvalid(c_rvalid), .s_axil_rready(c_rready),
        .s_axis_tdata(adc_beat), .s_axis_tvalid(1'b1), .s_axis_tready(),
        .m_axis_tdata(dac_beat), .m_axis_tvalid(), .m_axis_tready(1'b1),
        .ext_trig(1'b0), .trig_out(trig_out), .led(led));

    // ---------------- diagnostics: wave_snap on the DAC stream ----------
    reg  [31:0] s_awaddr = 0;  reg s_awvalid = 0;  wire s_awready;
    reg  [31:0] s_wdata = 0;   reg s_wvalid = 0;   wire s_wready;
    wire [1:0]  s_bresp;       wire s_bvalid;      reg s_bready = 1;
    reg  [31:0] s_araddr = 0;  reg s_arvalid = 0;  wire s_arready;
    wire [31:0] s_rdata;       wire [1:0] s_rresp; wire s_rvalid;
    reg         s_rready = 1;

    wave_snap #(.DATA_W(256), .DEPTH_LOG2(10), .ID_VALUE(32'hACE0_11F1))
    u_snap (
        .aclk(clk), .aresetn(rstn),
        .s_axil_awaddr(s_awaddr), .s_axil_awvalid(s_awvalid), .s_axil_awready(s_awready),
        .s_axil_wdata(s_wdata), .s_axil_wstrb(4'hF), .s_axil_wvalid(s_wvalid), .s_axil_wready(s_wready),
        .s_axil_bresp(s_bresp), .s_axil_bvalid(s_bvalid), .s_axil_bready(s_bready),
        .s_axil_araddr(s_araddr), .s_axil_arvalid(s_arvalid), .s_axil_arready(s_arready),
        .s_axil_rdata(s_rdata), .s_axil_rresp(s_rresp), .s_axil_rvalid(s_rvalid), .s_axil_rready(s_rready),
        .s_axis_tdata(dac_beat), .s_axis_tvalid(1'b1), .s_axis_tready(),
        .hw_trig(trig_out));

    // ---------------- mock cavity ----------------
    real g, c30, s30, tau_k;
    real y_i, y_q, u_i_r, u_q_r, pr_i, pr_q;
    reg signed [15:0] adc_i, adc_q;

    initial begin
        g = 0.5; c30 = 0.8660254; s30 = 0.5; tau_k = 1.0 / 16.0;
        y_i = 0.0; y_q = 0.0;
    end

    always @(posedge clk) begin
        u_i_r = $itor($signed(dac_beat[15:0]));
        u_q_r = $itor($signed(dac_beat[31:16]));
        // plant: rotate +30deg, gain 0.5, first-order lag, offset on I
        pr_i = g * (u_i_r * c30 - u_q_r * s30);
        pr_q = g * (u_i_r * s30 + u_q_r * c30);
        y_i  = y_i + tau_k * (pr_i - y_i);
        y_q  = y_q + tau_k * (pr_q - y_q);
        adc_i = $rtoi(y_i) + 50;       // static probe offset on I
        adc_q = $rtoi(y_q);
        adc_beat <= {{8{adc_q}}, {8{adc_i}}};
    end

    // ---------------- AXI-Lite master tasks (one set per bus) ----------
    task cwrite(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            c_awaddr = addr; c_awvalid = 1; c_wdata = data; c_wvalid = 1;
            wait (c_bvalid); @(negedge clk);
            c_awvalid = 0; c_wvalid = 0;
            wait (!c_bvalid);
        end
    endtask
    task cread(input [31:0] addr, output [31:0] data);
        begin
            @(negedge clk);
            c_araddr = addr; c_arvalid = 1;
            wait (c_rvalid); data = c_rdata; @(negedge clk);
            c_arvalid = 0;
            wait (!c_rvalid);
        end
    endtask
    task swrite(input [31:0] addr, input [31:0] data);
        begin
            @(negedge clk);
            s_awaddr = addr; s_awvalid = 1; s_wdata = data; s_wvalid = 1;
            wait (s_bvalid); @(negedge clk);
            s_awvalid = 0; s_wvalid = 0;
            wait (!s_bvalid);
        end
    endtask
    task sread(input [31:0] addr, output [31:0] data);
        begin
            @(negedge clk);
            s_araddr = addr; s_arvalid = 1;
            wait (s_rvalid); data = s_rdata; @(negedge clk);
            s_arvalid = 0;
            wait (!s_rvalid);
        end
    endtask

    integer errors = 0;
    reg [31:0] rd, rd2;
    integer mi, mq;
    integer trig_count = 0;
    always @(posedge clk) if (trig_out) trig_count = trig_count + 1;

    task check_near(input [127:0] name, input integer got,
                    input integer exp, input integer tol);
        if ((got > exp + tol) || (got < exp - tol)) begin
            $display("FAIL: %0s got %0d expected %0d (+/-%0d)",
                     name, got, exp, tol);
            errors = errors + 1;
        end else
            $display("  ok: %0s = %0d (target %0d +/-%0d)",
                     name, got, exp, tol);
    endtask

    function integer sext16(input [31:0] v);
        sext16 = $signed(v[15:0]);
    endfunction

    initial begin
        repeat (10) @(posedge clk);
        rstn = 1;
        repeat (10) @(posedge clk);

        // ---- sanity: ID registers on both blocks ----
        cread(32'h00, rd);
        if (rd !== 32'h11F0_0001) begin
            $display("FAIL: core ID %08x", rd); errors = errors + 1;
        end
        sread(32'h00, rd);
        if (rd !== 32'hACE0_11F1) begin
            $display("FAIL: snap ID %08x", rd); errors = errors + 1;
        end

        // ---- configure: undo the plant's +30deg, moderate gains ----
        cwrite(32'h0C, 4);              // DECIM: 2^4 = 16 -> 19.2 MHz strobe
        cwrite(32'h10, 8000);           // SP_I
        cwrite(32'h14, 4000);           // SP_Q
        cwrite(32'h18, 8192);           // KP = 0.25
        cwrite(32'h1C, 1638);           // KI = 0.05 per strobe
        cwrite(32'h28, 28377);          // ROT_C =  cos(-30) = 0.866
        cwrite(32'h2C, 32'hFFFFC000);   // ROT_S = -sin(30)  = -0.5 (-16384)
        cwrite(32'h30, 30000);          // LIM

        // ================= CW closed loop =================
        cwrite(32'h04, 32'h5);          // run=1, CW, fb_en=1
        repeat (60000) @(posedge clk);  // ~200 us: plenty for tau=16 plant

        cread(32'h48, rd);  mi = sext16(rd);
        cread(32'h4C, rd);  mq = sext16(rd);
        check_near("CW meas_i", mi, 8000, 64);
        check_near("CW meas_q", mq, 4000, 64);

        // drive should be nonzero and unsaturated
        cread(32'h08, rd);
        if (rd[9:8] !== 2'b00) begin
            $display("FAIL: unexpected saturation in CW (STATUS=%08x)", rd);
            errors = errors + 1;
        end

        // ================= pulsed mode =================
        cwrite(32'h04, 32'h0);          // stop (clears integrators)
        cwrite(32'h34, 8192);           // PERIOD
        cwrite(32'h38, 256);            // DELAY
        cwrite(32'h3C, 4096);           // WIDTH
        cwrite(32'h40, 1024);           // FB_DLY (wait for cavity fill)
        cwrite(32'h44, 3072);           // FB_WID (ends with rf_gate)
        swrite(32'h04, 32'h2);          // snap: arm on hardware trigger
        trig_count = 0;
        cwrite(32'h04, 32'h7);          // run=1, pulsed, fb_en=1

        repeat (6 * 8192) @(posedge clk);   // six pulses

        // between pulses the drive must be exactly zero
        // (park just after a period boundary, before DELAY)
        wait (trig_out); @(posedge clk); @(posedge clk);
        if (dac_beat !== 128'h0) begin
            $display("FAIL: drive nonzero outside rf_gate");
            errors = errors + 1;
        end else
            $display("  ok: drive gated off between pulses");

        // late in this pulse's feedback window, meas ~ setpoint
        repeat (3800) @(posedge clk);   // inside [1024,4096) window
        cread(32'h48, rd);  mi = sext16(rd);
        cread(32'h4C, rd);  mq = sext16(rd);
        check_near("pulsed meas_i", mi, 8000, 200);
        check_near("pulsed meas_q", mq, 4000, 200);

        if (trig_count < 6) begin
            $display("FAIL: only %0d triggers seen", trig_count);
            errors = errors + 1;
        end else
            $display("  ok: %0d pulse triggers", trig_count);

        // ---- capture: freeze, then check the snap recorded the pulse ----
        swrite(32'h04, 32'h0);          // trig_en off: last pulse frozen
        repeat (8192) @(posedge clk);
        sread(32'h08, rd);              // STATUS: done, not armed
        if (rd[1:0] !== 2'b01) begin
            $display("FAIL: snap STATUS %08x (want done=1,armed=0)", rd);
            errors = errors + 1;
        end else
            $display("  ok: snap capture complete");
        sread(32'h0C, rd);
        if (rd !== 32'd1024) begin
            $display("FAIL: snap DEPTH %0d", rd); errors = errors + 1;
        end
        // beat 0 (t=0, before DELAY): zero. beat 600 (t=600, gate open,
        // capture is beat-per-cycle here since tvalid is constant): nonzero.
        sread(32'h8000 + 0 * 32, rd);
        sread(32'h8000 + 600 * 32, rd2);
        if (rd !== 32'h0) begin
            $display("FAIL: snap beat0 %08x (want 0 - pre-gate)", rd);
            errors = errors + 1;
        end
        if (rd2 === 32'h0) begin
            $display("FAIL: snap beat600 is zero (want drive)");
            errors = errors + 1;
        end else
            $display("  ok: snap holds gated pulse (beat0=0, beat600=%08x)", rd2);

        if (errors == 0) $display("PASS: tb_llrf_loop (closed loop, both modes)");
        else             $display("FAIL: tb_llrf_loop (%0d errors)", errors);
        $finish;
    end

    initial begin
        #3_000_000;  // 3 ms wall-clock guard
        $display("FAIL: tb_llrf_loop timeout");
        $finish;
    end
endmodule
