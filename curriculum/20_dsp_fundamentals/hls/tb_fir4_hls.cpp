// Same three phases as sim/tb_fir4_transposed.v - impulse, saturating
// step, 500 "random" samples - against the same Q1.15 reference model,
// in C. (Deterministic LCG instead of $random: cosim reruns this exact
// bench against the generated RTL, and reproducibility beats randomness
// quality here.)

#include <cstdio>
#include <cstdint>
#include "ap_axi_sdata.h"
#include "hls_stream.h"

typedef ap_axiu<16, 0, 0, 0> sample_t;
void fir4_hls(hls::stream<sample_t> &s_axis, hls::stream<sample_t> &m_axis);

static int16_t hist[4] = {0, 0, 0, 0};

static int16_t model(int16_t x)
{
    hist[3] = hist[2]; hist[2] = hist[1]; hist[1] = hist[0]; hist[0] = x;
    int64_t acc = 0;
    static const int16_t COEF[4] = {3277, 13107, 13107, 3277};
    for (int k = 0; k < 4; k++) acc += (int32_t)hist[k] * COEF[k];
    int64_t rounded = (acc + 16384) >> 15;
    if (rounded > 32767) return 32767;
    if (rounded < -32768) return -32768;
    return (int16_t)rounded;
}

int main()
{
    hls::stream<sample_t> in_s, out_s;
    int errors = 0, n = 0;
    uint32_t lcg = 12345;

    auto feed_check = [&](int16_t x) {
        sample_t in;
        in.data = (uint16_t)x;
        in.last = 0; in.keep = -1; in.strb = -1;
        in_s.write(in);
        fir4_hls(in_s, out_s);
        int16_t exp = model(x);
        sample_t out = out_s.read();
        int16_t got = (int16_t)(uint16_t)out.data;
        if (got != exp) {
            if (errors < 10)
                printf("FAIL sample %d: in=%d got=%d exp=%d\n", n, x, got, exp);
            errors++;
        }
        n++;
    };

    feed_check(16384);                        // impulse +0.5
    for (int i = 0; i < 7; i++) feed_check(0);
    for (int i = 0; i < 10; i++) feed_check(32767);   // step: must saturate
    for (int i = 0; i < 6; i++) feed_check(0);
    for (int i = 0; i < 500; i++) {           // deterministic noise
        lcg = lcg * 1664525u + 1013904223u;
        feed_check((int16_t)(lcg >> 16));
    }

    if (errors == 0)
        printf("PASS: tb_fir4_hls - impulse, saturating step, and 500 samples match the Q1.15 model\n");
    else
        printf("FAIL: tb_fir4_hls - %d error(s)\n", errors);
    return errors ? 1 : 0;
}
