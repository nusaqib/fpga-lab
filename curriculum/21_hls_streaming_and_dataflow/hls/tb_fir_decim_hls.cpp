// Feed packets through the dataflow pipeline; model FIR + decimation in
// plain C; check every surviving beat's value and the TLAST re-framing
// (8 beats out per 16 in, TLAST on the 8th).

#include <cstdio>
#include <cstdint>
#include "ap_axi_sdata.h"
#include "hls_stream.h"

typedef ap_axiu<16, 0, 0, 0> sample_t;
void fir_decim_hls(hls::stream<sample_t> &s_axis, hls::stream<sample_t> &m_axis);

static int16_t hist[4] = {0, 0, 0, 0};
static int16_t fir_model(int16_t x)
{
    static const int16_t COEF[4] = {3277, 13107, 13107, 3277};
    hist[3] = hist[2]; hist[2] = hist[1]; hist[1] = hist[0]; hist[0] = x;
    int64_t acc = 0;
    for (int k = 0; k < 4; k++) acc += (int32_t)hist[k] * COEF[k];
    int64_t rounded = (acc + 16384) >> 15;
    if (rounded > 32767) return 32767;
    if (rounded < -32768) return -32768;
    return (int16_t)rounded;
}

int main()
{
    const unsigned PACKETS = 5, BEATS = 16;
    hls::stream<sample_t> in_s, out_s;
    int errors = 0;
    uint32_t lcg = 99;

    int16_t exp_data[PACKETS * BEATS / 2];
    bool    exp_last[PACKETS * BEATS / 2];
    unsigned n_exp = 0;

    for (unsigned p = 0; p < PACKETS; p++) {
        for (unsigned b = 0; b < BEATS; b++) {
            lcg = lcg * 1664525u + 1013904223u;
            int16_t x = (int16_t)(lcg >> 16);
            int16_t y = fir_model(x);
            if (b % 2 == 1) {                    // odd indices survive
                exp_data[n_exp] = y;
                exp_last[n_exp] = (b == BEATS - 1);
                n_exp++;
            }
            sample_t in;
            in.data = (uint16_t)x;
            in.last = (b == BEATS - 1);
            in.keep = -1; in.strb = -1;
            in_s.write(in);
            fir_decim_hls(in_s, out_s);
        }
    }

    for (unsigned i = 0; i < n_exp; i++) {
        if (out_s.empty()) {
            printf("FAIL: output dry at beat %u of %u\n", i, n_exp);
            return 1;
        }
        sample_t o = out_s.read();
        if ((int16_t)(uint16_t)o.data != exp_data[i] || (bool)o.last != exp_last[i]) {
            if (errors < 10)
                printf("FAIL beat %u: got=(%d,last=%d) exp=(%d,last=%d)\n",
                       i, (int16_t)(uint16_t)o.data, (int)o.last, exp_data[i], (int)exp_last[i]);
            errors++;
        }
    }
    if (!out_s.empty()) { printf("FAIL: extra beats in output\n"); errors++; }

    if (errors == 0)
        printf("PASS: tb_fir_decim_hls - %u packets filtered and decimated 16->8 with correct TLAST framing\n", PACKETS);
    else
        printf("FAIL: tb_fir_decim_hls - %d error(s)\n", errors);
    return errors ? 1 : 0;
}
