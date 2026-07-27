// C bench for the DDS: run it at a known phase_inc, unpack the beats,
// and check (a) amplitude, (b) frequency via zero crossings of I,
// (c) quadrature - Q must lag I by a quarter period (positive f).
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include "ap_axi_sdata.h"
#include "ap_int.h"
#include "hls_stream.h"

typedef ap_axiu<128, 0, 0, 0> beat_t;
void dds_hls(hls::stream<beat_t> &m_axis, ap_uint<32> phase_inc);

int main()
{
    hls::stream<beat_t> s;
    const int NBEATS = 512;                 // 2048 complex samples
    const int NSAMP = NBEATS * 4;
    // 1/64 of the sample rate: exactly 64 samples per period
    const ap_uint<32> inc = (ap_uint<32>)(0x100000000ULL / 64);

    for (int i = 0; i < NBEATS; i++)
        dds_hls(s, inc);

    static short si[NSAMP], sq[NSAMP];
    for (int b = 0; b < NBEATS; b++) {
        beat_t v = s.read();
        for (int k = 0; k < 4; k++) {
            si[b * 4 + k] = (short)(ap_int<16>)v.data(32 * k + 15, 32 * k);
            sq[b * 4 + k] = (short)(ap_int<16>)v.data(32 * k + 31, 32 * k + 16);
        }
    }

    int errors = 0;

    // amplitude: |I| peak near 13107
    short pk = 0;
    for (int i = 0; i < NSAMP; i++)
        if (abs(si[i]) > pk) pk = abs(si[i]);
    if (pk < 12800 || pk > 13107) {
        printf("FAIL: I peak %d, expected ~13107\n", pk);
        errors++;
    }

    // Checks start at sample 256: in RTL co-simulation the phase_inc
    // register write is not synchronized to the free-running kernel's
    // first beats (COSIM "non-self-synchronizing top I/O"), so the first
    // handful of samples may predate the register landing. Steady state
    // is what the check is about.
    const int SKIP = 256;

    // frequency: (2048-256) samples / 64 per period = 28 periods = 56 crossings
    int cross = 0;
    for (int i = SKIP + 1; i < NSAMP; i++)
        if ((si[i - 1] < 0) != (si[i] < 0)) cross++;
    if (cross < 54 || cross > 58) {
        printf("FAIL: %d crossings, expected ~56\n", cross);
        errors++;
    }

    // quadrature: Q(t) should equal I(t - 16 samples) (quarter of 64)
    int bad = 0;
    for (int i = SKIP; i < NSAMP; i++)
        if (abs(sq[i] - si[i - 16]) > 64) bad++;
    if (bad > 0) {
        printf("FAIL: quadrature mismatch on %d samples\n", bad);
        errors++;
    }

    if (errors == 0) {
        printf(">>> DDS csim PASSED (peak=%d crossings=%d)\n", pk, cross);
        return 0;
    }
    return 1;
}
