`timescale 1ns / 1ps

// The entire "transmitter" of module 22: a constant complex baseband
// sample, forever. The RFDC's fine mixer multiplies whatever the fabric
// supplies by its NCO's e^(j*2*pi*f*t) - so DC in means a pure carrier at
// the NCO frequency out. A tone generator with zero DSP in the fabric;
// the synthesizer is inside the converter tile.
//
// Lane layout (RFDC DAC, IQ data, 8 words/beat): 16-bit words interleaved
// I0,Q0,I1,Q1,... from the LSBs up, so each 32-bit chunk is {Q,I}.
// I = 0x4000 (0.5 of full scale, headroom for the mixer), Q = 0.
module dc_source (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 aclk CLK",
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF m_axis, ASSOCIATED_RESET aresetn" *)
    input          aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 aresetn RST",
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input          aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TDATA" *)
    output [127:0] m_axis_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TVALID" *)
    output         m_axis_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_axis TREADY" *)
    input          m_axis_tready
);

    assign m_axis_tdata  = {4{32'h0000_4000}};  // {Q=0, I=0.5FS} x4 pairs
    assign m_axis_tvalid = aresetn;             // data from the first live cycle

endmodule
