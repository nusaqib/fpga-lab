`timescale 1ns / 1ps

// The LLRF system's fabric core: AXI4-Lite register file + the whole
// control chain from DESIGN.md, between one ADC beat stream in and one
// DAC beat stream out.
//
//   s_axis (256b, 8 IQ/beat) -> beat mean -> 2^N decimate -> rotate
//     -> PI(I), PI(Q) -> drive hold -> {4x replicate, rf_gate} -> m_axis
//
// pulse_gen provides rf_gate / fb_gate / trig; trig is exported so the
// wave_snap diagnostics buffers can re-arm on every pulse. See
// DESIGN.md for the register map - offsets here MUST stay in sync with
// it and with src/llrf_regs.h.
module llrf_core (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil:s_axis:m_axis, ASSOCIATED_RESET aresetn" *)
    input             aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input             aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
    input      [31:0] s_axil_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
    input             s_axil_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
    output reg        s_axil_awready = 1'b0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
    input      [31:0] s_axil_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
    input      [3:0]  s_axil_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
    input             s_axil_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
    output reg        s_axil_wready = 1'b0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
    output reg [1:0]  s_axil_bresp = 2'b00,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
    output reg        s_axil_bvalid = 1'b0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
    input             s_axil_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
    input      [31:0] s_axil_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
    input             s_axil_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
    output reg        s_axil_arready = 1'b0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
    output reg [31:0] s_axil_rdata = 32'h0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
    output reg [1:0]  s_axil_rresp = 2'b00,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
    output reg        s_axil_rvalid = 1'b0,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
    input             s_axil_rready,

    // cavity probe, from the RFDC ADC (via axis_combiner, module 24 layout)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input      [255:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input              s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output             s_axis_tready,

    // cavity drive, to the RFDC DAC (4 {Q,I} pairs per beat)
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output     [127:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output             m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input              m_axis_tready,

    input              ext_trig,     // machine trigger (tie 0 if unused)
    output             trig_out,     // to wave_snap hw_trig inputs
    output     [3:0]   led           // bring-up: run / rf_gate / fb_gate / sat
);
    localparam [31:0] ID_VALUE = 32'h11F0_0001;
    localparam [1:0]  RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;

    assign s_axis_tready = 1'b1;
    assign m_axis_tvalid = 1'b1;   // the DAC never stalls in this design

    wire rst = !aresetn;

    // ------------------------------------------------------------------
    // registers
    // ------------------------------------------------------------------
    reg        ctrl_run = 1'b0, ctrl_mode = 1'b0,
               ctrl_fb_en = 1'b0, ctrl_ext_trig = 1'b0;
    reg [3:0]  r_decim = 4'd8;
    reg signed [15:0] r_sp_i = 16'sd0,  r_sp_q = 16'sd0;
    reg signed [15:0] r_kp = 16'sd0,    r_ki = 16'sd0;
    reg signed [15:0] r_ff_i = 16'sd0,  r_ff_q = 16'sd0;
    reg signed [15:0] r_rot_c = 16'sd32767, r_rot_s = 16'sd0;
    reg [15:0] r_lim = 16'd32767;
    reg [31:0] r_period = 32'd307200;   // 1 ms default
    reg [31:0] r_delay = 32'd0, r_width = 32'd30720;
    reg [31:0] r_fb_dly = 32'd0, r_fb_wid = 32'd30720;

    // ------------------------------------------------------------------
    // datapath
    // ------------------------------------------------------------------
    wire signed [15:0] mean_i, mean_q;
    wire mean_v;
    iq_beat_mean u_mean (
        .clk(aclk), .rst(rst),
        .beat(s_axis_tdata), .beat_valid(s_axis_tvalid),
        .mean_i(mean_i), .mean_q(mean_q), .mean_valid(mean_v));

    wire signed [15:0] dec_i, dec_q;
    wire dec_v;
    dec_pow2 u_dec (
        .clk(aclk), .rst(rst), .n(r_decim),
        .in_i(mean_i), .in_q(mean_q), .in_valid(mean_v),
        .out_i(dec_i), .out_q(dec_q), .out_valid(dec_v));

    wire signed [15:0] rot_i, rot_q;
    wire rot_v;
    iq_rotate u_rot (
        .clk(aclk), .rst(rst), .c(r_rot_c), .s(r_rot_s),
        .in_i(dec_i), .in_q(dec_q), .in_valid(dec_v),
        .out_i(rot_i), .out_q(rot_q), .out_valid(rot_v));

    wire trig, rf_gate, fb_gate;
    pulse_gen u_pg (
        .clk(aclk), .rst(rst), .run(ctrl_run), .mode(ctrl_mode),
        .ext_trig_en(ctrl_ext_trig), .ext_trig(ext_trig),
        .period(r_period), .delay(r_delay), .width(r_width),
        .fb_dly(r_fb_dly), .fb_wid(r_fb_wid),
        .trig(trig), .rf_gate(rf_gate), .fb_gate(fb_gate));
    assign trig_out = trig;

    wire signed [15:0] drv_i, drv_q;
    wire sat_i, sat_q;
    pi_ctrl u_pi_i (
        .clk(aclk), .rst(rst), .run(ctrl_run),
        .fb_en(ctrl_fb_en), .fb_gate(fb_gate),
        .sp(r_sp_i), .kp(r_kp), .ki(r_ki), .ff(r_ff_i), .lim(r_lim),
        .meas(rot_i), .strobe(rot_v), .drive(drv_i), .sat_evt(sat_i));
    pi_ctrl u_pi_q (
        .clk(aclk), .rst(rst), .run(ctrl_run),
        .fb_en(ctrl_fb_en), .fb_gate(fb_gate),
        .sp(r_sp_q), .kp(r_kp), .ki(r_ki), .ff(r_ff_q), .lim(r_lim),
        .meas(rot_q), .strobe(rot_v), .drive(drv_q), .sat_evt(sat_q));

    // drive replicated into all four beat lanes, gated by rf_gate
    assign m_axis_tdata = (ctrl_run && rf_gate) ? {4{drv_q, drv_i}} : 128'h0;

    // sticky saturation flags, cleared by any CTRL write
    reg sat_i_st = 1'b0, sat_q_st = 1'b0;

    // readback sample-and-hold
    reg signed [15:0] rb_raw_i = 16'sd0, rb_raw_q = 16'sd0;
    reg signed [15:0] rb_meas_i = 16'sd0, rb_meas_q = 16'sd0;
    always @(posedge aclk) begin
        if (dec_v) begin rb_raw_i  <= dec_i; rb_raw_q  <= dec_q; end
        if (rot_v) begin rb_meas_i <= rot_i; rb_meas_q <= rot_q; end
    end

    // bring-up LEDs: gates stretched to eye speed (~50 ms at 307.2 MHz)
    reg [23:0] str_rf = 24'd0, str_fb = 24'd0;
    always @(posedge aclk) begin
        str_rf <= rf_gate ? 24'hFFFFFF : (str_rf == 0 ? 24'd0 : str_rf - 1);
        str_fb <= fb_gate ? 24'hFFFFFF : (str_fb == 0 ? 24'd0 : str_fb - 1);
    end
    assign led = {sat_i_st | sat_q_st, |str_fb, |str_rf, ctrl_run};

    // ------------------------------------------------------------------
    // AXI4-Lite (module 15's proven skeleton)
    // ------------------------------------------------------------------
    reg        aw_got = 1'b0, w_got = 1'b0;
    reg [31:0] awaddr_l = 32'h0, wdata_l = 32'h0;
    wire do_write = aw_got && w_got && !s_axil_bvalid;

    always @(posedge aclk) begin
        if (rst) begin
            s_axil_awready <= 1'b0; s_axil_wready <= 1'b0;
            s_axil_bvalid <= 1'b0;  s_axil_bresp <= RESP_OKAY;
            aw_got <= 1'b0; w_got <= 1'b0;
            ctrl_run <= 1'b0; ctrl_mode <= 1'b0;
            ctrl_fb_en <= 1'b0; ctrl_ext_trig <= 1'b0;
            sat_i_st <= 1'b0; sat_q_st <= 1'b0;
        end else begin
            sat_i_st <= sat_i_st | sat_i;
            sat_q_st <= sat_q_st | sat_q;

            s_axil_awready <= !aw_got && !s_axil_bvalid;
            if (s_axil_awready && s_axil_awvalid) begin
                awaddr_l <= s_axil_awaddr;
                aw_got   <= 1'b1;
                s_axil_awready <= 1'b0;
            end
            s_axil_wready <= !w_got && !s_axil_bvalid;
            if (s_axil_wready && s_axil_wvalid) begin
                wdata_l <= s_axil_wdata;
                w_got   <= 1'b1;
                s_axil_wready <= 1'b0;
            end
            if (do_write) begin
                s_axil_bresp <= RESP_OKAY;
                case (awaddr_l[7:2])
                    6'h01: begin                       // CTRL
                        {ctrl_ext_trig, ctrl_fb_en, ctrl_mode, ctrl_run}
                            <= wdata_l[3:0];
                        sat_i_st <= 1'b0;              // CTRL write clears
                        sat_q_st <= 1'b0;
                    end
                    6'h03: r_decim  <= (wdata_l[3:0] > 4'd12) ? 4'd12
                                                              : wdata_l[3:0];
                    6'h04: r_sp_i   <= wdata_l[15:0];
                    6'h05: r_sp_q   <= wdata_l[15:0];
                    6'h06: r_kp     <= wdata_l[15:0];
                    6'h07: r_ki     <= wdata_l[15:0];
                    6'h08: r_ff_i   <= wdata_l[15:0];
                    6'h09: r_ff_q   <= wdata_l[15:0];
                    6'h0A: r_rot_c  <= wdata_l[15:0];
                    6'h0B: r_rot_s  <= wdata_l[15:0];
                    6'h0C: r_lim    <= {1'b0, wdata_l[14:0]};  // keep positive
                    6'h0D: r_period <= wdata_l;
                    6'h0E: r_delay  <= wdata_l;
                    6'h0F: r_width  <= wdata_l;
                    6'h10: r_fb_dly <= wdata_l;
                    6'h11: r_fb_wid <= wdata_l;
                    default: s_axil_bresp <= RESP_SLVERR;
                endcase
                if (awaddr_l[31:8] != 24'h0)
                    s_axil_bresp <= RESP_SLVERR;
                s_axil_bvalid <= 1'b1;
                aw_got <= 1'b0;
                w_got  <= 1'b0;
            end
            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;
        end
    end

    always @(posedge aclk) begin
        if (rst) begin
            s_axil_arready <= 1'b0; s_axil_rvalid <= 1'b0;
            s_axil_rresp <= RESP_OKAY; s_axil_rdata <= 32'h0;
        end else begin
            s_axil_arready <= !s_axil_rvalid;
            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_arready <= 1'b0;
                s_axil_rvalid  <= 1'b1;
                s_axil_rresp   <= RESP_OKAY;
                case (s_axil_araddr[7:2])
                    6'h00: s_axil_rdata <= ID_VALUE;
                    6'h01: s_axil_rdata <= {28'h0, ctrl_ext_trig, ctrl_fb_en,
                                            ctrl_mode, ctrl_run};
                    6'h02: s_axil_rdata <= {22'h0, sat_q_st, sat_i_st,
                                            6'h0, fb_gate, rf_gate};
                    6'h03: s_axil_rdata <= {28'h0, r_decim};
                    6'h04: s_axil_rdata <= {{16{r_sp_i[15]}},  r_sp_i};
                    6'h05: s_axil_rdata <= {{16{r_sp_q[15]}},  r_sp_q};
                    6'h06: s_axil_rdata <= {{16{r_kp[15]}},    r_kp};
                    6'h07: s_axil_rdata <= {{16{r_ki[15]}},    r_ki};
                    6'h08: s_axil_rdata <= {{16{r_ff_i[15]}},  r_ff_i};
                    6'h09: s_axil_rdata <= {{16{r_ff_q[15]}},  r_ff_q};
                    6'h0A: s_axil_rdata <= {{16{r_rot_c[15]}}, r_rot_c};
                    6'h0B: s_axil_rdata <= {{16{r_rot_s[15]}}, r_rot_s};
                    6'h0C: s_axil_rdata <= {16'h0, r_lim};
                    6'h0D: s_axil_rdata <= r_period;
                    6'h0E: s_axil_rdata <= r_delay;
                    6'h0F: s_axil_rdata <= r_width;
                    6'h10: s_axil_rdata <= r_fb_dly;
                    6'h11: s_axil_rdata <= r_fb_wid;
                    6'h12: s_axil_rdata <= {{16{rb_meas_i[15]}}, rb_meas_i};
                    6'h13: s_axil_rdata <= {{16{rb_meas_q[15]}}, rb_meas_q};
                    6'h14: s_axil_rdata <= {{16{drv_i[15]}},     drv_i};
                    6'h15: s_axil_rdata <= {{16{drv_q[15]}},     drv_q};
                    6'h16: s_axil_rdata <= {{16{rb_raw_i[15]}},  rb_raw_i};
                    6'h17: s_axil_rdata <= {{16{rb_raw_q[15]}},  rb_raw_q};
                    default: begin
                        s_axil_rdata <= 32'hDEAD_DEAD;
                        s_axil_rresp <= RESP_SLVERR;
                    end
                endcase
                if (s_axil_araddr[31:8] != 24'h0) begin
                    s_axil_rdata <= 32'hDEAD_DEAD;
                    s_axil_rresp <= RESP_SLVERR;
                end
            end
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
        end
    end
endmodule
