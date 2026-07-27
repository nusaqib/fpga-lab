/* Module 23: digital up/down conversion - the RFDC as a tunable radio.
 *
 * Same bitstream as module 22 (DAC_A -> SMA cable -> ADC_A, constant
 * I=0.5FS into the DAC fine mixer). Everything interesting here happens
 * at RUNTIME through the xrfdc driver:
 *
 *   A. Fine-mixer NCO sweep: step the ADC NCO across the 1 GHz carrier
 *      and watch the baseband beat track |f_carrier - f_nco| - this is
 *      what "tuning a receiver" IS in a direct-RF system.
 *   B. Coarse mixer at fs/4: the multiply-free mixer (samples get
 *      multiplied by 1, j, -1, -j - just sign swaps and lane swaps).
 *      Fixed frequencies only; that's the price of free.
 *   C. Runtime decimation change (2x -> 4x): the tone doesn't move, the
 *      sample rate does - crossings per capture halve, and only the
 *      arithmetic that knows the new rate reads 100 MHz again.
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

#ifdef XPAR_AXIS_SNAP_0_BASEADDR
#define SNAP_BASE XPAR_AXIS_SNAP_0_BASEADDR
#else
#define SNAP_BASE 0xA0100000UL
#endif
#define SNAP_CTRL   (SNAP_BASE + 0x0004)
#define SNAP_STATUS (SNAP_BASE + 0x0008)
#define SNAP_BUF    (SNAP_BASE + 0x8000)

#define RF_TILE       2
#define DAC_NCO_MHZ   1000.0
#define ADC_FS_MSPS   4915.2          /* tile sample rate                */
#define N_BEATS       1024
#define N_SAMP        (N_BEATS * 8)

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

static int16_t samples[N_SAMP];

/* ---------- plumbing (same recipe as module 22) ---------- */

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

/* Apply mixer settings to every enabled block of tile 2 of `type`. */
static int for_each_block_set_mixer(u32 type, XRFdc_Mixer_Settings *tmpl)
{
    int hits = 0;
    for (u32 blk = 0; blk < 4; blk++) {
        int en = (type == XRFDC_DAC_TILE)
                     ? XRFdc_IsDACBlockEnabled(&rfdc, RF_TILE, blk)
                     : XRFdc_IsADCBlockEnabled(&rfdc, RF_TILE, blk);
        if (!en)
            continue;
        XRFdc_Mixer_Settings mix;
        if (XRFdc_GetMixerSettings(&rfdc, type, RF_TILE, blk, &mix) != XRFDC_SUCCESS)
            return -1;
        mix.MixerType      = tmpl->MixerType;
        mix.MixerMode      = tmpl->MixerMode;
        mix.CoarseMixFreq  = tmpl->CoarseMixFreq;
        mix.Freq           = tmpl->Freq;
        mix.PhaseOffset    = 0.0;
        mix.FineMixerScale = XRFDC_MIXER_SCALE_1P0;
        mix.EventSource    = XRFDC_EVNT_SRC_TILE;
        if (XRFdc_SetMixerSettings(&rfdc, type, RF_TILE, blk, &mix) != XRFDC_SUCCESS)
            return -1;
        XRFdc_UpdateEvent(&rfdc, type, RF_TILE, blk, XRFDC_EVENT_MIXER);
        hits++;
    }
    return hits;
}

static int adc_fine_nco(double freq_mhz)
{
    XRFdc_Mixer_Settings m = { 0 };
    m.MixerType     = XRFDC_MIXER_TYPE_FINE;
    m.MixerMode     = XRFDC_MIXER_MODE_R2C;
    m.CoarseMixFreq = XRFDC_COARSE_MIX_OFF;
    m.Freq          = freq_mhz;
    return for_each_block_set_mixer(XRFDC_ADC_TILE, &m) > 0 ? XST_SUCCESS
                                                            : XST_FAILURE;
}

static int adc_coarse_fs4(void)
{
    XRFdc_Mixer_Settings m = { 0 };
    m.MixerType     = XRFDC_MIXER_TYPE_COARSE;
    m.MixerMode     = XRFDC_MIXER_MODE_R2C;
    m.CoarseMixFreq = XRFDC_COARSE_MIX_SAMPLE_FREQ_BY_FOUR;
    m.Freq          = 0.0;
    return for_each_block_set_mixer(XRFDC_ADC_TILE, &m) > 0 ? XST_SUCCESS
                                                            : XST_FAILURE;
}

/* ---------- measurement ---------- */

static void capture(void)
{
    Xil_Out32(SNAP_CTRL, 1);
    while ((Xil_In32(SNAP_STATUS) & 1) == 0)
        ;
    for (int b = 0; b < N_BEATS; b++)
        for (int w = 0; w < 4; w++) {
            uint32_t v = Xil_In32(SNAP_BUF + b * 16 + w * 4);
            samples[b * 8 + w * 2]     = (int16_t)(v & 0xFFFF);
            samples[b * 8 + w * 2 + 1] = (int16_t)(v >> 16);
        }
}

/* Returns measured frequency in kHz given the CURRENT I-sample rate. */
static int measure_khz(double fs_msps, int *pkpk_out)
{
    int16_t vmin = 32767, vmax = -32768;
    int64_t acc = 0;
    for (int i = 0; i < N_SAMP; i++) {
        if (samples[i] < vmin) vmin = samples[i];
        if (samples[i] > vmax) vmax = samples[i];
        acc += samples[i];
    }
    int32_t mean = (int32_t)(acc / N_SAMP);
    int crossings = 0;
    for (int i = 1; i < N_SAMP; i++)
        if ((samples[i - 1] - mean < 0) != (samples[i] - mean < 0))
            crossings++;
    if (pkpk_out)
        *pkpk_out = vmax - vmin;
    return (int)((int64_t)crossings * (int64_t)(fs_msps * 1000.0)
                 / (2 * (N_SAMP - 1)));
}

static int expect_khz(int measured, int expected, int tol)
{
    int d = measured - expected;
    if (d < 0) d = -d;
    return d <= tol;
}

int main(void)
{
    int fails = 0;

    xil_printf("\r\n=== module 23: digital up/down conversion ===\r\n");
    if (rfclk_program() != XST_SUCCESS) { xil_printf("FAIL: rfclk\r\n"); return 1; }
    usleep(100000);
    if (rfdc_init() != XST_SUCCESS) { xil_printf("FAIL: rfdc init\r\n"); return 1; }
    if (rfdc_start_tiles() != XST_SUCCESS) { xil_printf("FAIL: tiles\r\n"); return 1; }
    xil_printf("tiles running, PLLs locked\r\n");

    /* transmitter: fixed 1 GHz carrier, exactly like module 22 */
    XRFdc_Mixer_Settings dacm = { 0 };
    dacm.MixerType     = XRFDC_MIXER_TYPE_FINE;
    dacm.MixerMode     = XRFDC_MIXER_MODE_C2R;
    dacm.CoarseMixFreq = XRFDC_COARSE_MIX_OFF;
    dacm.Freq          = DAC_NCO_MHZ;
    if (for_each_block_set_mixer(XRFDC_DAC_TILE, &dacm) <= 0) {
        xil_printf("FAIL: DAC mixer\r\n");
        return 1;
    }

    double fs_i = ADC_FS_MSPS / 2.0;   /* IP static config: decimate 2x */

    xil_printf("\r\n-- A. fine NCO sweep (carrier fixed at 1000 MHz) --\r\n");
    xil_printf("  NCO MHz | expect kHz | measured kHz | pk-pk | verdict\r\n");
    static const int ncos[] = { -800, -850, -900, -950, -1050, -1100, -1200 };
    for (unsigned i = 0; i < sizeof(ncos) / sizeof(ncos[0]); i++) {
        adc_fine_nco((double)ncos[i]);
        usleep(1000);
        capture();
        int pkpk;
        int khz = measure_khz(fs_i, &pkpk);
        int exp = abs(1000 + ncos[i]) * 1000;
        int ok = expect_khz(khz, exp, exp / 10 + 2000) && pkpk > 4000;
        xil_printf("  %7d | %10d | %12d | %5d | %s\r\n",
                   ncos[i], exp, khz, pkpk, ok ? "ok" : "WRONG");
        if (!ok) fails++;
    }

    xil_printf("\r\n-- B. coarse mixer fs/4 (multiply-free) --\r\n");
    if (adc_coarse_fs4() != XST_SUCCESS) {
        xil_printf("FAIL: coarse mixer setup\r\n");
        fails++;
    } else {
        usleep(1000);
        capture();
        int pkpk;
        int khz = measure_khz(fs_i, &pkpk);
        /* fs/4 = 1228.8 MHz; beat = 1228.8 - 1000 = 228.8 MHz */
        int exp = 228800;
        int ok = expect_khz(khz, exp, 25000) && pkpk > 4000;
        xil_printf("  fs/4 = 1228.8 MHz -> expect %d kHz, measured %d kHz, pk-pk %d: %s\r\n",
                   exp, khz, pkpk, ok ? "ok" : "WRONG");
        if (!ok) fails++;
    }

    xil_printf("\r\n-- C. runtime decimation 2x -> 4x --\r\n");
    adc_fine_nco(-900.0);   /* back to a 100 MHz beat */
    usleep(1000);
    capture();
    int pkpk2, khz2 = measure_khz(fs_i, &pkpk2);
    xil_printf("  dec 2x: %d kHz at %d MSPS (pk-pk %d)\r\n",
               khz2, (int)fs_i, pkpk2);

    int rc = XRFdc_SetDecimationFactor(&rfdc, RF_TILE, 0, XRFDC_INTERP_DECIM_4X);
    /* dual-tile block numbering strikes again: try block 1 if 0 refuses */
    if (rc != XRFDC_SUCCESS)
        rc = XRFdc_SetDecimationFactor(&rfdc, RF_TILE, 1, XRFDC_INTERP_DECIM_4X);
    if (rc != XRFDC_SUCCESS) {
        xil_printf("  SetDecimationFactor failed\r\n");
        fails++;
    } else {
        usleep(10000);
        capture();
        int pkpk4, khz4_wrong = measure_khz(fs_i, &pkpk4);
        int khz4 = measure_khz(fs_i / 2.0, NULL);
        xil_printf("  dec 4x: same math as before reads %d kHz - WRONG on purpose\r\n",
                   khz4_wrong);
        xil_printf("  dec 4x: with fs=%d MSPS it reads %d kHz (pk-pk %d)\r\n",
                   (int)(fs_i / 2.0), khz4, pkpk4);
        int ok = expect_khz(khz4, 100000, 12000) && pkpk4 > 4000 &&
                 expect_khz(khz4_wrong, 200000, 24000);
        xil_printf("  tone stayed at 100 MHz; only the sample rate moved: %s\r\n",
                   ok ? "ok" : "WRONG");
        if (!ok) fails++;
    }

    if (fails == 0)
        xil_printf("\r\nPASS: all DUC/DDC experiments\r\n");
    else
        xil_printf("\r\nFAIL: %d experiment(s) off - check the SMA loopback\r\n",
                   fails);

    while (1)
        __asm__ volatile("wfi");
    return 0;
}
