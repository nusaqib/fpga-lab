// C testbench for the HLS scaler - the same checks tb_axis_pipeline.v
// made in Verilog for module 12 (values x3, TLAST every BEATS-th beat),
// minus the backpressure hostility: C simulation has no concept of
// TREADY timing. That's an honest limitation of csim worth internalizing
// - it verifies the FUNCTION, not the protocol. `make hls-cosim` closes
// that gap by rerunning this same bench against the generated Verilog in
// xsim, where real handshake timing exists.
//
// Prints the repo-standard PASS/FAIL line that make greps for.

#include <cstdio>
#include "ap_axi_sdata.h"
#include "hls_stream.h"

typedef ap_axiu<32, 0, 0, 0> beat_t;

void axis_scaler_hls(hls::stream<beat_t> &s_axis,
                     hls::stream<beat_t> &m_axis);

int main()
{
    const unsigned PACKETS = 5, BEATS = 16, SCALE = 3;
    hls::stream<beat_t> in_s, out_s;
    int errors = 0;
    unsigned value = 0;

    for (unsigned p = 0; p < PACKETS; p++) {
        for (unsigned b = 0; b < BEATS; b++) {
            beat_t beat;
            beat.data = value++;
            beat.last = (b == BEATS - 1);
            beat.keep = -1;
            beat.strb = -1;
            in_s.write(beat);
            axis_scaler_hls(in_s, out_s);   // one call = one beat (II=1 model)
        }
    }

    value = 0;
    for (unsigned p = 0; p < PACKETS; p++) {
        for (unsigned b = 0; b < BEATS; b++) {
            if (out_s.empty()) {
                printf("FAIL: output stream ran dry at packet %u beat %u\n", p, b);
                return 1;
            }
            beat_t beat = out_s.read();
            unsigned expect = value * SCALE;
            if (beat.data != expect) {
                errors++;
                printf("FAIL beat %u: data=%u exp=%u\n", value, (unsigned)beat.data, expect);
            }
            if (beat.last != (b == BEATS - 1)) {
                errors++;
                printf("FAIL beat %u: tlast misplaced\n", value);
            }
            value++;
        }
    }

    if (errors == 0)
        printf("PASS: tb_axis_scaler_hls - %u packets x %u beats scaled and framed correctly\n",
               PACKETS, BEATS);
    else
        printf("FAIL: tb_axis_scaler_hls - %d error(s)\n", errors);
    return errors ? 1 : 0;
}
