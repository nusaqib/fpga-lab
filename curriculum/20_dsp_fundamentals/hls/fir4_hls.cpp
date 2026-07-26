// The same 4-tap Q1.15 boxcar FIR as hdl/fir4_transposed.v, in HLS C++.
//
// Deliberately written with explicit integer arithmetic (ap_int types,
// same round-half-up and saturation as the Verilog) rather than
// ap_fixed: the goal of this module is BIT-EXACT agreement between the
// hand-written RTL, this C++, and one shared reference model - explicit
// shifts and clamps make the quantization visible and portable across
// all three. ap_fixed<16,1,AP_RND,AP_SAT> would express the same thing
// more compactly once you trust it; see the README for the mapping.
//
// Note the different natural structure: the C loop reads like the FIR
// *equation* (direct form - shift history, multiply-accumulate), while
// the Verilog is written in the *transposed* form that matches DSP48
// cascades. PIPELINE II=1 + complete partitioning lets HLS restructure
// into whatever it deems best for the target - check the csynth report
// to see how many DSPs it actually chose.

#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_stream.h"

typedef ap_axiu<16, 0, 0, 0> sample_t;

void fir4_hls(hls::stream<sample_t> &s_axis,
              hls::stream<sample_t> &m_axis)
{
#pragma HLS INTERFACE mode=axis port=s_axis
#pragma HLS INTERFACE mode=axis port=m_axis
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS PIPELINE II=1 style=flp

    static const ap_int<16> COEF[4] = {3277, 13107, 13107, 3277};
    static ap_int<16> hist[4] = {0, 0, 0, 0};
#pragma HLS ARRAY_PARTITION variable=hist complete
#pragma HLS ARRAY_PARTITION variable=COEF complete

    sample_t in = s_axis.read();

    hist[3] = hist[2];
    hist[2] = hist[1];
    hist[1] = hist[0];
    hist[0] = ap_int<16>(in.data);

    ap_int<34> acc = 0;
    for (int k = 0; k < 4; k++) {
#pragma HLS UNROLL
        ap_int<32> prod = ap_int<32>(hist[k]) * COEF[k];   // Q2.30
#pragma HLS BIND_OP variable=prod op=mul impl=dsp
        acc += prod;
    }

    // round to nearest, saturate Q4.30 -> Q1.15 (same as the Verilog)
    ap_int<34> rounded = (acc + 16384) >> 15;
    ap_int<16> result;
    if (rounded > 32767)        result = 32767;
    else if (rounded < -32768)  result = -32768;
    else                        result = ap_int<16>(rounded);

    sample_t out;
    out.data = result;
    out.last = in.last;
    out.keep = in.keep;
    out.strb = in.strb;
    m_axis.write(out);
}
