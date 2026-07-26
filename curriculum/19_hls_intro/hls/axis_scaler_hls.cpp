// Module 12's axis_scaler, re-expressed as ~15 lines of C++ for Vitis HLS.
//
// The comparison is the whole point: the hand-written Verilog version
// needed an explicit skid buffer - two data registers, occupancy
// accounting, a registered-ready equation derived by hand, and a
// testbench that caught a dropped-beat bug in the first draft. Here, the
// PIPELINE pragma asks for one beat per cycle and the tool synthesizes
// whatever handshake registering that requires. The cost of the
// convenience is inspectability: open the generated Verilog
// (_out/hls/<board>/axis_scaler_hls/hls/impl/verilog/) next to module
// 12's axis_scaler.v and see which one you could debug at 2am.
//
// hls::stream + ap_axiu = an AXI-Stream interface with TDATA/TLAST (the
// axis INTERFACE pragma maps them to a real AXIS port). ap_ctrl_none
// means no start/done handshake - the block just runs, like RTL does.

#include "ap_axi_sdata.h"
#include "hls_stream.h"

typedef ap_axiu<32, 0, 0, 0> beat_t;   // 32b TDATA + TLAST (+TKEEP/TSTRB)

static const unsigned SCALE = 3;        // same constant as module 12

void axis_scaler_hls(hls::stream<beat_t> &s_axis,
                     hls::stream<beat_t> &m_axis)
{
#pragma HLS INTERFACE mode=axis port=s_axis
#pragma HLS INTERFACE mode=axis port=m_axis
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS PIPELINE II=1 style=flp

    beat_t in = s_axis.read();

    beat_t out;
    out.data = in.data * SCALE;
    out.last = in.last;
    out.keep = in.keep;
    out.strb = in.strb;

    m_axis.write(out);
}
