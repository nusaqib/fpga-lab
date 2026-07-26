// A two-stage streaming kernel: module 20's 4-tap FIR followed by a
// decimate-by-2, connected by an INTERNAL hls::stream and scheduled with
// #pragma HLS DATAFLOW - the module's headline concept.
//
// DATAFLOW is task-level parallelism: without it, HLS would run
// fir_stage to completion, then decim_stage (sequential functions, like
// C). With it, both stages become concurrently-running processes with a
// FIFO between them - exactly the axis_counter_src -> axis_scaler ->
// axis_capture structure module 12 built by hand out of three RTL
// blocks, except here the whole pipeline lives inside one C function and
// the tool builds the FIFOs. PIPELINE II=1 (instruction-level, within a
// stage) and DATAFLOW (task-level, between stages) compose; the
// distinction is the lesson.
//
// Decimation halves the rate: a 16-beat packet in -> 8 beats out. TLAST
// is re-framed onto the last surviving beat of each packet (the odd-
// indexed samples are the kept ones, so the input's TLAST beat - index
// 15 - is itself a kept sample and carries TLAST out).

#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_stream.h"

typedef ap_axiu<16, 0, 0, 0> sample_t;

// Internal-stream payload: the ap_axiu sideband type is only legal on
// INTERFACE ports (HLS 214-208, found the direct way) - between dataflow
// stages you pass your own struct and keep just what matters.
struct mid_t {
    ap_int<16> data;
    bool       last;
};

static void fir_stage(hls::stream<sample_t> &in, hls::stream<mid_t> &out)
{
    static const ap_int<16> COEF[4] = {3277, 13107, 13107, 3277};
    static ap_int<16> hist[4] = {0, 0, 0, 0};
#pragma HLS ARRAY_PARTITION variable=hist complete
#pragma HLS ARRAY_PARTITION variable=COEF complete
#pragma HLS PIPELINE II=1 style=flp

    sample_t s = in.read();
    hist[3] = hist[2]; hist[2] = hist[1]; hist[1] = hist[0];
    hist[0] = ap_int<16>(s.data);

    ap_int<34> acc = 0;
    for (int k = 0; k < 4; k++) {
#pragma HLS UNROLL
        acc += ap_int<32>(hist[k]) * COEF[k];
    }
    ap_int<34> rounded = (acc + 16384) >> 15;
    ap_int<16> r;
    if (rounded > 32767)       r = 32767;
    else if (rounded < -32768) r = -32768;
    else                       r = ap_int<16>(rounded);

    mid_t o;
    o.data = r;
    o.last = s.last;
    out.write(o);
}

static void decim_stage(hls::stream<mid_t> &in, hls::stream<sample_t> &out)
{
#pragma HLS PIPELINE II=1 style=flp
    static bool keep = false;   // drop sample 0, keep sample 1, drop, keep...

    mid_t s = in.read();
    if (keep || s.last) {       // never swallow the packet boundary
        sample_t o;
        o.data = s.data;
        o.last = s.last;
        o.keep = -1;
        o.strb = -1;
        out.write(o);
    }
    keep = !keep;
    if (s.last)
        keep = false;           // packets stay phase-aligned
}

void fir_decim_hls(hls::stream<sample_t> &s_axis,
                   hls::stream<sample_t> &m_axis)
{
#pragma HLS INTERFACE mode=axis port=s_axis
#pragma HLS INTERFACE mode=axis port=m_axis
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS DATAFLOW

    static hls::stream<mid_t> mid("fir_to_decim");
#pragma HLS STREAM variable=mid depth=4

    fir_stage(s_axis, mid);
    decim_stage(mid, m_axis);
}
