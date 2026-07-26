`timescale 1ns / 1ps

// AXI-Stream sink with an AXI4-Lite window into what it saw - the
// observation endpoint of the module's pipeline. Always ready (a pure
// consumer), it records the last TDATA, counts beats and packets, and
// exposes everything over the same AXI4-Lite register style as module 11.
//
// Register map:
//   0x00  LAST_DATA  RO  most recent beat's TDATA
//   0x04  BEATS      RO  total beats consumed
//   0x08  PKTS       RO  total TLAST-terminated packets
//   0x0C  ID         RO  constant 0xA715_CA90
// Any write -> SLVERR (everything here is read-only).
module axis_capture (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axis:s_axil, ASSOCIATED_RESET aresetn, FREQ_HZ 100000000" *)
    input             aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input             aresetn,

    // stream in
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TDATA" *)
    input      [31:0] s_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TVALID" *)
    input             s_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TLAST" *)
    input             s_axis_tlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_axis TREADY" *)
    output            s_axis_tready,

    // AXI4-Lite status window
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
    input      [31:0] s_axil_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
    input             s_axil_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
    output reg        s_axil_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
    input      [31:0] s_axil_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
    input      [3:0]  s_axil_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
    input             s_axil_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
    output reg        s_axil_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
    output reg [1:0]  s_axil_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
    output reg        s_axil_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
    input             s_axil_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
    input      [31:0] s_axil_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
    input             s_axil_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
    output reg        s_axil_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
    output reg [31:0] s_axil_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
    output reg [1:0]  s_axil_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
    output reg        s_axil_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
    input             s_axil_rready,

    output [3:0]      led    // low bits of the beat counter, for a pulse
);

    localparam [1:0] RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;

    // ---- stream side: always ready, just observe ----
    assign s_axis_tready = 1'b1;

    reg [31:0] last_data = 0, beat_count = 0, pkt_count = 0;

    always @(posedge aclk) begin
        if (!aresetn) begin
            last_data  <= 0;
            beat_count <= 0;
            pkt_count  <= 0;
        end else if (s_axis_tvalid) begin
            last_data  <= s_axis_tdata;
            beat_count <= beat_count + 1'b1;
            if (s_axis_tlast)
                pkt_count <= pkt_count + 1'b1;
        end
    end

    assign led = beat_count[3:0];

    // ---- AXI4-Lite read path (same shape as module 11) ----
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b0;
            s_axil_rresp   <= RESP_OKAY;
            s_axil_rdata   <= 32'h0;
        end else begin
            s_axil_arready <= !s_axil_rvalid;
            if (s_axil_arready && s_axil_arvalid) begin
                s_axil_arready <= 1'b0;
                s_axil_rvalid  <= 1'b1;
                s_axil_rresp   <= RESP_OKAY;
                case (s_axil_araddr[3:2])
                    2'd0: s_axil_rdata <= last_data;
                    2'd1: s_axil_rdata <= beat_count;
                    2'd2: s_axil_rdata <= pkt_count;
                    2'd3: s_axil_rdata <= 32'hA715_CA90;
                endcase
                if (s_axil_araddr[31:4] != 28'h0) begin
                    s_axil_rdata <= 32'hDEAD_DEAD;
                    s_axil_rresp <= RESP_SLVERR;
                end
            end
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;
        end
    end

    // ---- AXI4-Lite write path: everything is RO -> SLVERR ----
    reg aw_got = 1'b0, w_got = 1'b0;
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_awready <= 1'b0;
            s_axil_wready  <= 1'b0;
            s_axil_bvalid  <= 1'b0;
            s_axil_bresp   <= RESP_OKAY;
            aw_got <= 1'b0;
            w_got  <= 1'b0;
        end else begin
            s_axil_awready <= !aw_got && !s_axil_bvalid;
            if (s_axil_awready && s_axil_awvalid) begin
                aw_got <= 1'b1;
                s_axil_awready <= 1'b0;
            end
            s_axil_wready <= !w_got && !s_axil_bvalid;
            if (s_axil_wready && s_axil_wvalid) begin
                w_got <= 1'b1;
                s_axil_wready <= 1'b0;
            end
            if (aw_got && w_got && !s_axil_bvalid) begin
                s_axil_bresp  <= RESP_SLVERR;
                s_axil_bvalid <= 1'b1;
                aw_got <= 1'b0;
                w_got  <= 1'b0;
            end
            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;
        end
    end

endmodule
