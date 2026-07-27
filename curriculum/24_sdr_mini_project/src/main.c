/* Module 24: mini SDR - programmable transmitter, spectrum-analyzer receiver.
 *
 * TX: the HLS DDS synthesizes a complex baseband tone at f_off (set by
 *     writing phase_inc over AXI4-Lite); the DAC fine mixer shifts it to
 *     1 GHz + f_off on the DAC_A SMA.
 * RX: ADC fine mixer at -1000 MHz brings it back to f_off; I and Q are
 *     captured TOGETHER (one 256-bit beat = 8 simultaneous complex
 *     samples) and a 1024-point FFT on the A53 turns them into a
 *     spectrum.
 *
 * The payoff over module 23's single-component measurements: with I AND
 * Q, positive and negative frequencies are different things. The sweep
 * puts tones on both sides of DC and checks the peak lands on the
 * correct SIDE, not just at the correct distance.
 */
#include <stdint.h>
#include <stdlib.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xstatus.h"
#include "sleep.h"
#include "metal/sys.h"
#include "xrfdc.h"
#include "rfclk.h"

#ifdef XPAR_AXIS_SNAP_IQ_0_BASEADDR
#define SNAP_BASE XPAR_AXIS_SNAP_IQ_0_BASEADDR
#else
#define SNAP_BASE 0xA0100000UL
#endif
#define SNAP_CTRL   (SNAP_BASE + 0x0004)
#define SNAP_STATUS (SNAP_BASE + 0x0008)
#define SNAP_BUF    (SNAP_BASE + 0x8000)

#ifdef XPAR_DDS_HLS_0_BASEADDR
#define DDS_BASE XPAR_DDS_HLS_0_BASEADDR
#else
#define DDS_BASE 0xA0120000UL
#endif
/* s_axilite scalar register offset from the generated HLS driver header
 * (xdds_hls_hw.h in the packaged IP): data register of phase_inc. */
#define DDS_PHASE_INC (DDS_BASE + 0x10)

#define RF_TILE      2
#define DAC_NCO_MHZ  1000.0
#define ADC_NCO_MHZ  -1000.0
#define DAC_BB_MSPS  1228.8    /* DDS output rate (4 cplx/beat @ 307.2M) */
#define ADC_BB_MSPS  2457.6    /* captured complex rate (2x decimation)  */
#define N_BEATS      1024
#define NFFT         1024

static XRFdc rfdc;
static struct metal_device *rfdc_dev = NULL;
static metal_phys_addr_t rfdc_phys;
static struct metal_device rfdc_metal_dev = {
    .name = NULL, .bus = NULL, .num_regions = 1,
    .regions = { { .virt = NULL, .physmap = &rfdc_phys, .size = 0x40000,
                   .page_shift = (unsigned)(-1), .page_mask = (unsigned)(-1),
                   .mem_flags = 0, .ops = { NULL } } },
    .node = { NULL }, .irq_num = 0, .irq_info = NULL,
};

static int16_t si[N_BEATS * 8], sq[N_BEATS * 8];
static double re[NFFT], im[NFFT], mag2[NFFT];

/* ---------- RFDC plumbing (module 22/23 recipe) ---------- */

static int rfdc_init(void)
{
    struct metal_init_params init_param = METAL_INIT_DEFAULTS;
    if (metal_init(&init_param))
        return XST_FAILURE;
    XRFdc_Config *cfg = XRFdc_LookupConfig(XPAR_XRFDC_0_BASEADDR);
    if (cfg == NULL)
        return XST_FAILURE;
    rfdc_phys = cfg->BaseAddr;
    rfdc_metal_dev.name = cfg->Name;
    rfdc_metal_dev.regions[0].virt = (void *)cfg->BaseAddr;
    rfdc_dev = &rfdc_metal_dev;
    if (XRFdc_RegisterMetal(&rfdc, 0, &rfdc_dev) != XRFDC_SUCCESS)
        return XST_FAILURE;
    return (XRFdc_CfgInitialize(&rfdc, cfg) == XRFDC_SUCCESS)
               ? XST_SUCCESS : XST_FAILURE;
}

static int rfdc_start_tiles(void)
{
    XRFdc_Reset(&rfdc, XRFDC_DAC_TILE, RF_TILE);
    XRFdc_Reset(&rfdc, XRFDC_ADC_TILE, RF_TILE);
    for (int tries = 0; tries < 100; tries++) {
        XRFdc_IPStatus ip;
        if (XRFdc_GetIPStatus(&rfdc, &ip) != XRFDC_SUCCESS)
            return XST_FAILURE;
        if (ip.DACTileStatus[RF_TILE].TileState == 15 &&
            ip.ADCTileStatus[RF_TILE].TileState == 15)
            return (ip.DACTileStatus[RF_TILE].PLLState &&
                    ip.ADCTileStatus[RF_TILE].PLLState) ? XST_SUCCESS
                                                        : XST_FAILURE;
        usleep(10000);
    }
    return XST_FAILURE;
}

static int set_mixers(void)
{
    int hits = 0;
    for (u32 blk = 0; blk < 4; blk++) {
        if (XRFdc_IsDACBlockEnabled(&rfdc, RF_TILE, blk)) {
            XRFdc_Mixer_Settings m;
            XRFdc_GetMixerSettings(&rfdc, XRFDC_DAC_TILE, RF_TILE, blk, &m);
            m.MixerType = XRFDC_MIXER_TYPE_FINE;
            m.MixerMode = XRFDC_MIXER_MODE_C2R;
            m.CoarseMixFreq = XRFDC_COARSE_MIX_OFF;
            m.Freq = DAC_NCO_MHZ;
            m.PhaseOffset = 0.0;
            m.FineMixerScale = XRFDC_MIXER_SCALE_1P0;
            m.EventSource = XRFDC_EVNT_SRC_TILE;
            if (XRFdc_SetMixerSettings(&rfdc, XRFDC_DAC_TILE, RF_TILE, blk, &m)
                    != XRFDC_SUCCESS)
                return XST_FAILURE;
            XRFdc_UpdateEvent(&rfdc, XRFDC_DAC_TILE, RF_TILE, blk, XRFDC_EVENT_MIXER);
            hits++;
        }
        if (XRFdc_IsADCBlockEnabled(&rfdc, RF_TILE, blk)) {
            XRFdc_Mixer_Settings m;
            XRFdc_GetMixerSettings(&rfdc, XRFDC_ADC_TILE, RF_TILE, blk, &m);
            m.MixerType = XRFDC_MIXER_TYPE_FINE;
            m.MixerMode = XRFDC_MIXER_MODE_R2C;
            m.CoarseMixFreq = XRFDC_COARSE_MIX_OFF;
            m.Freq = ADC_NCO_MHZ;
            m.PhaseOffset = 0.0;
            m.FineMixerScale = XRFDC_MIXER_SCALE_1P0;
            m.EventSource = XRFDC_EVNT_SRC_TILE;
            if (XRFdc_SetMixerSettings(&rfdc, XRFDC_ADC_TILE, RF_TILE, blk, &m)
                    != XRFDC_SUCCESS)
                return XST_FAILURE;
            XRFdc_UpdateEvent(&rfdc, XRFDC_ADC_TILE, RF_TILE, blk, XRFDC_EVENT_MIXER);
            hits++;
        }
    }
    return hits >= 2 ? XST_SUCCESS : XST_FAILURE;
}

/* ---------- TX control ---------- */

static void dds_set_freq_mhz(double f_off)
{
    /* phase_inc = f / f_sample * 2^32, two's complement for negative f */
    double cycles = f_off / DAC_BB_MSPS;
    int64_t inc = (int64_t)(cycles * 4294967296.0);
    Xil_Out32(DDS_PHASE_INC, (uint32_t)(int32_t)inc);
}

/* ---------- RX capture ---------- */

static void capture(void)
{
    Xil_Out32(SNAP_CTRL, 1);
    while ((Xil_In32(SNAP_STATUS) & 1) == 0)
        ;
    for (int b = 0; b < N_BEATS; b++) {
        for (int w = 0; w < 4; w++) {          /* words 0-3: I lanes */
            uint32_t v = Xil_In32(SNAP_BUF + b * 32 + w * 4);
            si[b * 8 + w * 2]     = (int16_t)(v & 0xFFFF);
            si[b * 8 + w * 2 + 1] = (int16_t)(v >> 16);
        }
        for (int w = 0; w < 4; w++) {          /* words 4-7: Q lanes */
            uint32_t v = Xil_In32(SNAP_BUF + b * 32 + 16 + w * 4);
            sq[b * 8 + w * 2]     = (int16_t)(v & 0xFFFF);
            sq[b * 8 + w * 2 + 1] = (int16_t)(v >> 16);
        }
    }
}

/* ---------- 1024-point complex FFT, no libm ----------
 * Iterative radix-2 DIT. The only trig needed is cos/sin(2*pi/2^s) for
 * s = 1..10 - eleven constants, written out below; every other twiddle
 * comes from the rotation recurrence. Doubles keep the recurrence error
 * far below the quantization noise of 16-bit samples. */
static const double WCOS[11] = {
    0.0,                    /* s=0 unused */
    -1.0,                   /* cos(2pi/2)    */
    0.0,                    /* cos(2pi/4)    */
    0.70710678118654752,    /* cos(2pi/8)    */
    0.92387953251128676,    /* cos(2pi/16)   */
    0.98078528040323044,    /* cos(2pi/32)   */
    0.99518472667219689,    /* cos(2pi/64)   */
    0.99879545620517239,    /* cos(2pi/128)  */
    0.99969881869620422,    /* cos(2pi/256)  */
    0.99992470183914452,    /* cos(2pi/512)  */
    0.99998117528260114,    /* cos(2pi/1024) */
};
static const double WSIN[11] = {
    0.0,
    0.0,                    /* sin(2pi/2)    */
    1.0,                    /* sin(2pi/4)    */
    0.70710678118654752,
    0.38268343236508977,
    0.19509032201612827,
    0.09801714032956060,
    0.04906767432741802,
    0.02454122852291229,
    0.01227153828571993,
    0.00613588464915448,
};

static void fft1024(void)
{
    /* bit-reverse permutation (NFFT = 1024 = 10 bits) */
    for (int i = 0; i < NFFT; i++) {
        unsigned r = 0, x = i;
        for (int b = 0; b < 10; b++) { r = (r << 1) | (x & 1); x >>= 1; }
        if (r > (unsigned)i) {
            double t;
            t = re[i]; re[i] = re[r]; re[r] = t;
            t = im[i]; im[i] = im[r]; im[r] = t;
        }
    }
    for (int s = 1; s <= 10; s++) {
        int len = 1 << s, half = len >> 1;
        /* forward transform: w steps by e^(-j*2pi/len) */
        double wc = WCOS[s], ws = -WSIN[s];
        for (int i = 0; i < NFFT; i += len) {
            double cr = 1.0, ci = 0.0;
            for (int j = 0; j < half; j++) {
                int a = i + j, b = a + half;
                double tr = re[b] * cr - im[b] * ci;
                double ti = re[b] * ci + im[b] * cr;
                re[b] = re[a] - tr;  im[b] = im[a] - ti;
                re[a] = re[a] + tr;  im[a] = im[a] + ti;
                double ncr = cr * wc - ci * ws;
                ci = cr * ws + ci * wc;
                cr = ncr;
            }
        }
    }
}

/* Returns the peak bin as a SIGNED frequency in kHz (DC region excluded). */
static int spectrum_peak_khz(double *peak_mag2)
{
    for (int i = 0; i < NFFT; i++) {
        re[i] = (double)si[i];
        im[i] = (double)sq[i];
    }
    fft1024();
    for (int i = 0; i < NFFT; i++)
        mag2[i] = re[i] * re[i] + im[i] * im[i];

    int best = -1;
    double bm = 0.0;
    for (int k = 0; k < NFFT; k++) {
        int signed_bin = (k <= NFFT / 2) ? k : k - NFFT;
        if (signed_bin >= -3 && signed_bin <= 3)
            continue;                       /* skip DC + mixer leakage */
        if (mag2[k] > bm) { bm = mag2[k]; best = k; }
    }
    if (peak_mag2)
        *peak_mag2 = bm;
    int signed_bin = (best <= NFFT / 2) ? best : best - NFFT;
    return (int)((int64_t)signed_bin * (int64_t)(ADC_BB_MSPS * 1000.0) / NFFT);
}

/* crude integer log2 for the ASCII display */
static int ilog2d(double v)
{
    int n = 0;
    while (v > 2.0 && n < 60) { v *= 0.5; n++; }
    return n;
}

static void print_spectrum(void)
{
    /* 64 columns spanning -fs/2 .. +fs/2, each the max of 16 bins */
    int h[64];
    for (int c = 0; c < 64; c++) {
        double m = 0.0;
        for (int j = 0; j < 16; j++) {
            int signed_bin = c * 16 + j - NFFT / 2;   /* -512..511 */
            int k = signed_bin < 0 ? signed_bin + NFFT : signed_bin;
            if (mag2[k] > m) m = mag2[k];
        }
        h[c] = ilog2d(m + 1.0);
    }
    int hmax = 1;
    for (int c = 0; c < 64; c++)
        if (h[c] > hmax) hmax = h[c];
    for (int row = 7; row >= 0; row--) {
        char line[65];
        for (int c = 0; c < 64; c++)
            line[c] = (h[c] * 8 / (hmax + 1) >= row) ? '#' : ' ';
        line[64] = 0;
        xil_printf("|%s|\r\n", line);
    }
    xil_printf("-1228.8 MHz %44s +1228.8 MHz\r\n", "0");
}

int main(void)
{
    xil_printf("\r\n=== module 24: mini SDR (DDS TX + FFT spectrum RX) ===\r\n");
    if (rfclk_program() != XST_SUCCESS) { xil_printf("FAIL: rfclk\r\n"); return 1; }
    usleep(100000);
    if (rfdc_init() != XST_SUCCESS) { xil_printf("FAIL: rfdc init\r\n"); return 1; }
    if (rfdc_start_tiles() != XST_SUCCESS) { xil_printf("FAIL: tiles\r\n"); return 1; }
    if (set_mixers() != XST_SUCCESS) { xil_printf("FAIL: mixers\r\n"); return 1; }
    xil_printf("tiles running, carrier 1 GHz, ADC NCO -1 GHz\r\n");

    /* Sign calibration: mixer conventions between DAC C2R and ADC R2C
     * decide whether the spectrum reads normal or conjugated. Send a
     * known +240 MHz and look where it lands - then hold every later
     * check to that orientation. Discovering this (not assuming it) is
     * the point of doing SDR bare-metal. */
    dds_set_freq_mhz(240.0);
    usleep(2000);
    capture();
    double pm;
    int cal = spectrum_peak_khz(&pm);
    int flip = (cal < 0) ? -1 : 1;
    xil_printf("calibration: +240 MHz landed at %d kHz -> spectrum %s\r\n",
               cal, flip == 1 ? "normal" : "CONJUGATED (noting for checks)");

    static const int tones_mhz[] = { 240, -240, 480, -720, 96 };
    int fails = 0;
    xil_printf("\r\n tone MHz | peak kHz (sign-corrected) | verdict\r\n");
    for (unsigned t = 0; t < sizeof(tones_mhz) / sizeof(tones_mhz[0]); t++) {
        dds_set_freq_mhz((double)tones_mhz[t]);
        usleep(2000);
        capture();
        int khz = spectrum_peak_khz(&pm) * flip;
        int exp = tones_mhz[t] * 1000;
        int tol = 5000;   /* +-2 bins of 2.4 MHz */
        int ok = (khz > exp - tol) && (khz < exp + tol) && pm > 1e6;
        xil_printf("  %7d | %25d | %s\r\n", tones_mhz[t], khz, ok ? "ok" : "WRONG");
        if (!ok) fails++;
        if (t == 0) {
            xil_printf("\r\nspectrum with the +240 MHz tone:\r\n");
            print_spectrum();
            xil_printf("\r\n");
        }
    }

    if (fails == 0)
        xil_printf("\r\nPASS: every tone found at the right frequency AND sign\r\n");
    else
        xil_printf("\r\nFAIL: %d tone(s) misplaced - check the SMA loopback\r\n", fails);

    while (1)
        __asm__ volatile("wfi");
    return 0;
}
