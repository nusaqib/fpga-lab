// Module 24's transmitter: a direct digital synthesizer in HLS - the
// Tier 7 skill applied to the Tier 8 machine. A 32-bit phase accumulator
// indexes 1024-entry cos/sin ROMs; four complex samples leave per beat
// (the RFDC DAC takes 4 I/Q pairs per 128-bit AXIS word). phase_inc is
// an AXI4-Lite register the A53 writes at runtime:
//
//     f_baseband = phase_inc / 2^32 * 1228.8 MHz   (signed - negative
//                  phase_inc gives a negative frequency, which the I/Q
//                  spectrum in main.c can actually SEE, unlike module
//                  23's single-component capture)
//
// The DAC's fine mixer then shifts this to 1 GHz + f_baseband on the SMA.
#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_stream.h"
#include "dds_tab.h"

typedef ap_axiu<128, 0, 0, 0> beat_t;

void dds_hls(hls::stream<beat_t> &m_axis, ap_uint<32> phase_inc)
{
#pragma HLS INTERFACE mode=axis port=m_axis
#pragma HLS INTERFACE mode=s_axilite port=phase_inc
#pragma HLS INTERFACE mode=ap_ctrl_none port=return
#pragma HLS PIPELINE II=1 style=flp

    static ap_uint<32> acc = 0;

    beat_t b;
    for (int k = 0; k < 4; k++) {
#pragma HLS UNROLL
        ap_uint<32> ph  = acc + (ap_uint<32>)(phase_inc * k);
        ap_uint<DDS_TAB_LOG2> idx = ph >> (32 - DDS_TAB_LOG2);
        ap_int<16> i = DDS_COS[idx];
        ap_int<16> q = DDS_SIN[idx];
        b.data(32 * k + 15, 32 * k)      = i;   // even 16-bit word: I
        b.data(32 * k + 31, 32 * k + 16) = q;   // odd  16-bit word: Q
    }
    acc += phase_inc * 4;

    b.keep = -1;
    b.strb = -1;
    b.last = 0;
    m_axis.write(b);
}
