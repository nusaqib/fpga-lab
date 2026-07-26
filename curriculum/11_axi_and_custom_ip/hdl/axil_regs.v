`timescale 1ns / 1ps

// A hand-written AXI4-Lite slave: four 32-bit registers. Writing one of
// these from scratch once is the fastest way to actually understand AXI -
// after this, every AXI IP you meet is "this, with more counters".
//
// Register map (word-addressed, byte addresses):
//   0x00  SCRATCH  RW  free 32-bit scratch register
//   0x04  LED      RW  [3:0] drive the board LEDs
//   0x08  STATUS   RO  [3:0] switches, [8] button (writes ignored)
//   0x0C  ID       RO  constant 0xF19A_1AB0 (sanity/discovery)
//
// AXI4-Lite in five channels: the master sends an address on AW (writes)
// or AR (reads), data on W, and the slave answers on B (write response)
// or R (read data). Every channel is a valid/ready handshake - transfer
// happens on the cycle both are high, either side may stall freely. This
// slave keeps it simple and safe:
//  - accepts AW and W in any order (latches each when it arrives, executes
//    the write when it has both),
//  - one outstanding transaction at a time (ready lines drop while a
//    response is pending),
//  - out-of-range addresses return SLVERR instead of silently aliasing.
// The X_INTERFACE_INFO attributes below tell IP integrator explicitly
// that these ports form one AXI4-Lite slave interface (and which clock
// and reset it's associated with), so the block-design module-reference
// flow groups them into a single connectable interface pin instead of
// guessing from names.
module axil_regs (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axil, ASSOCIATED_RESET aresetn, FREQ_HZ 100000000" *)
    input             aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input             aresetn,     // AXI reset is active-LOW by convention

    // write address channel
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWADDR" *)
    input      [31:0] s_axil_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWVALID" *)
    input             s_axil_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil AWREADY" *)
    output reg        s_axil_awready,
    // write data channel
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WDATA" *)
    input      [31:0] s_axil_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WSTRB" *)
    input      [3:0]  s_axil_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WVALID" *)
    input             s_axil_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil WREADY" *)
    output reg        s_axil_wready,
    // write response channel
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BRESP" *)
    output reg [1:0]  s_axil_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BVALID" *)
    output reg        s_axil_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil BREADY" *)
    input             s_axil_bready,
    // read address channel
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARADDR" *)
    input      [31:0] s_axil_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARVALID" *)
    input             s_axil_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil ARREADY" *)
    output reg        s_axil_arready,
    // read data channel
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RDATA" *)
    output reg [31:0] s_axil_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RRESP" *)
    output reg [1:0]  s_axil_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RVALID" *)
    output reg        s_axil_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 s_axil RREADY" *)
    input             s_axil_rready,

    // the actual hardware behind the registers
    output     [3:0]  led,
    input      [3:0]  sw,
    input             btn
);

    localparam [1:0] RESP_OKAY   = 2'b00,
                     RESP_SLVERR = 2'b10;

    localparam ID_VALUE = 32'hF19A_1AB0;

    reg [31:0] scratch_reg = 32'h0;
    reg [31:0] led_reg     = 32'h0;

    assign led = led_reg[3:0];

    // ---------------- write path ----------------
    // Latch AW and W independently; execute when both have arrived.
    reg        aw_got = 1'b0, w_got = 1'b0;
    reg [31:0] awaddr_l = 32'h0;
    reg [31:0] wdata_l  = 32'h0;
    reg [3:0]  wstrb_l  = 4'h0;

    wire do_write = aw_got && w_got && !s_axil_bvalid;

    integer bi;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axil_awready <= 1'b0;
            s_axil_wready  <= 1'b0;
            s_axil_bvalid  <= 1'b0;
            s_axil_bresp   <= RESP_OKAY;
            aw_got <= 1'b0;
            w_got  <= 1'b0;
            scratch_reg <= 32'h0;
            led_reg     <= 32'h0;
        end else begin
            // accept address (once per transaction)
            s_axil_awready <= !aw_got && !s_axil_bvalid;
            if (s_axil_awready && s_axil_awvalid) begin
                awaddr_l <= s_axil_awaddr;
                aw_got   <= 1'b1;
                s_axil_awready <= 1'b0;
            end
            // accept data (once per transaction)
            s_axil_wready <= !w_got && !s_axil_bvalid;
            if (s_axil_wready && s_axil_wvalid) begin
                wdata_l <= s_axil_wdata;
                wstrb_l <= s_axil_wstrb;
                w_got   <= 1'b1;
                s_axil_wready <= 1'b0;
            end
            // execute + respond
            if (do_write) begin
                s_axil_bresp <= RESP_OKAY;
                case (awaddr_l[3:2])   // word address within the map
                    2'd0: for (bi = 0; bi < 4; bi = bi + 1)
                              if (wstrb_l[bi]) scratch_reg[bi*8 +: 8] <= wdata_l[bi*8 +: 8];
                    2'd1: for (bi = 0; bi < 4; bi = bi + 1)
                              if (wstrb_l[bi]) led_reg[bi*8 +: 8] <= wdata_l[bi*8 +: 8];
                    default: ;   // RO/absent: swallow data, flag below
                endcase
                if (awaddr_l[31:4] != 28'h0 || awaddr_l[3:2] > 2'd1)
                    s_axil_bresp <= RESP_SLVERR;   // RO or out of range
                s_axil_bvalid <= 1'b1;
                aw_got <= 1'b0;
                w_got  <= 1'b0;
            end
            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;
        end
    end

    // ---------------- read path ----------------
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
                    2'd0: s_axil_rdata <= scratch_reg;
                    2'd1: s_axil_rdata <= led_reg;
                    2'd2: s_axil_rdata <= {23'b0, btn, 4'b0, sw};
                    2'd3: s_axil_rdata <= ID_VALUE;
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

endmodule
