`timescale 1ns / 1ps

// Waveform recorder for diagnostics - module 24's axis_snap_iq, grown
// two features for LLRF duty:
//   - parametrizable beat width (both tile-2 streams happen to be
//     256-bit today; the buffer readout geometry adapts to DATA_W),
//   - hardware trigger arming: with CTRL.b1 set, every pulse_gen trigger
//     re-arms the capture, so the buffer always holds the most recent
//     pulse - clear b1 and the last pulse stays frozen for readout.
//
// Register map (byte addresses):
//   0x0000  ID      RO  ID_VALUE
//   0x0004  CTRL    W   b0 = soft arm (self-clearing), b1 = arm on hw trig
//   0x0008  STATUS  RO  b0 = done, b1 = armed, b2 = hw-trig arming enabled
//   0x000C  DEPTH   RO  beats per capture
//   0x8000+ BUF     RO  captured beats, DATA_W/8 bytes each, 32-bit words
module wave_snap #(
    parameter DATA_W     = 256,
    parameter DEPTH_LOG2 = 10,
    parameter ID_VALUE   = 32'hACE0_11F1
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil:s_axis, ASSOCIATED_RESET aresetn" *)
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

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input      [DATA_W-1:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input                   s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output                  s_axis_tready,

    input                   hw_trig      // 1-cycle pulse from pulse_gen
);
    localparam DEPTH = 1 << DEPTH_LOG2;
    // byte offset bits consumed by one beat (5 for 256-bit, 4 for 128-bit)
    localparam BEAT_LOG2 = $clog2(DATA_W / 8);
    localparam [1:0] RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;

    assign s_axis_tready = 1'b1;

    // ------------- capture engine -------------
    (* ram_style = "block" *)
    reg [DATA_W-1:0] mem [0:DEPTH-1];
    reg [DEPTH_LOG2-1:0] wr_idx = 0;
    reg armed = 1'b0, done = 1'b0;
    reg arm_pulse = 1'b0;
    reg trig_en = 1'b0;

    wire arm_now = arm_pulse || (trig_en && hw_trig);

    always @(posedge aclk) begin
        if (!aresetn) begin
            armed  <= 1'b0;
            done   <= 1'b0;
            wr_idx <= 0;
        end else begin
            if (arm_now) begin
                armed  <= 1'b1;
                done   <= 1'b0;
                wr_idx <= 0;
            end else if (armed && s_axis_tvalid) begin
                wr_idx <= wr_idx + 1'b1;
                if (wr_idx == DEPTH - 1) begin
                    armed <= 1'b0;
                    done  <= 1'b1;
                end
            end
        end
    end

    always @(posedge aclk)
        if (armed && s_axis_tvalid)
            mem[wr_idx] <= s_axis_tdata;

    // ------------- write path (CTRL only) -------------
    reg        aw_got = 1'b0, w_got = 1'b0;
    reg [31:0] awaddr_l = 32'h0;
    reg [31:0] wdata_l  = 32'h0;
    wire do_write = aw_got && w_got && !s_axil_bvalid;

    always @(posedge aclk) begin
        arm_pulse <= 1'b0;
        if (!aresetn) begin
            s_axil_awready <= 1'b0;
            s_axil_wready  <= 1'b0;
            s_axil_bvalid  <= 1'b0;
            s_axil_bresp   <= RESP_OKAY;
            aw_got  <= 1'b0;
            w_got   <= 1'b0;
            trig_en <= 1'b0;
        end else begin
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
                if (awaddr_l[15:0] == 16'h0004) begin
                    s_axil_bresp <= RESP_OKAY;
                    arm_pulse    <= wdata_l[0];
                    trig_en      <= wdata_l[1];
                end else begin
                    s_axil_bresp <= RESP_SLVERR;
                end
                s_axil_bvalid <= 1'b1;
                aw_got <= 1'b0;
                w_got  <= 1'b0;
            end
            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;
        end
    end

    // ------------- read path (two-cycle, BRAM then word mux) -------------
    reg              r_wait = 1'b0;
    reg [31:0]       araddr_l = 32'h0;
    reg [DATA_W-1:0] bram_q = {DATA_W{1'b0}};

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b0;
            s_axil_rresp   <= RESP_OKAY;
            s_axil_rdata   <= 32'h0;
            r_wait         <= 1'b0;
        end else begin
            s_axil_arready <= !s_axil_rvalid && !r_wait;
            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_arready <= 1'b0;
                araddr_l <= s_axil_araddr;
                bram_q   <= mem[s_axil_araddr[BEAT_LOG2 +: DEPTH_LOG2]];
                r_wait   <= 1'b1;
            end else if (r_wait) begin
                r_wait        <= 1'b0;
                s_axil_rvalid <= 1'b1;
                s_axil_rresp  <= RESP_OKAY;
                if (araddr_l[15]) begin
                    s_axil_rdata <= bram_q[araddr_l[BEAT_LOG2-1:2]*32 +: 32];
                end else begin
                    case (araddr_l[3:2])
                        2'd0: s_axil_rdata <= ID_VALUE;
                        2'd1: s_axil_rdata <= 32'h0;
                        2'd2: s_axil_rdata <= {29'b0, trig_en, armed, done};
                        2'd3: s_axil_rdata <= DEPTH;
                    endcase
                    if (araddr_l[14:4] != 11'h0) begin
                        s_axil_rdata <= 32'hDEAD_DEAD;
                        s_axil_rresp <= RESP_SLVERR;
                    end
                end
            end
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
        end
    end
endmodule
