/* Module 22: the RFSoC does RF - bare-metal RFDC bring-up + loopback.
 *
 * Cable: DAC_A SMA -> ADC_A SMA (both on the tile-2 pair).
 *
 * Sequence, and why each step exists:
 *   1. Program LMK04828 + 2x LMX2594 over PS SPI0 (rfclk.c). Until this
 *      runs the RF tiles have no sample clock and sit dead in their boot
 *      state machine - the single biggest "why doesn't my RFSoC work"
 *      trap, and the reason this module exists.
 *   2. Restart the tiles (XRFdc_Reset) so their state machines re-run
 *      with a live clock, then poll until they reach the running state
 *      and the tile PLLs report lock.
 *   3. Point the NCOs: DAC fine mixer to +1000 MHz (so the constant
 *      I=0.5FS from the fabric becomes a 1 GHz carrier), ADC fine mixer
 *      to -900 MHz (so the received 1 GHz lands at 100 MHz baseband).
 *   4. Arm the axis_snap recorder, read back 8192 I-samples at
 *      2457.6 MSPS, and measure the frequency by counting zero
 *      crossings. Loopback present => ~100 MHz. No cable => noise.
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

/* --- axis_snap register map (see hdl/axis_snap.v) --- */
#ifdef XPAR_AXIS_SNAP_0_BASEADDR
#define SNAP_BASE XPAR_AXIS_SNAP_0_BASEADDR
#else
#define SNAP_BASE 0xA0100000UL   /* pinned in bd/rfdc_loopback_sys.tcl */
#endif
#define SNAP_ID     (SNAP_BASE + 0x0000)
#define SNAP_CTRL   (SNAP_BASE + 0x0004)
#define SNAP_STATUS (SNAP_BASE + 0x0008)
#define SNAP_DEPTH  (SNAP_BASE + 0x000C)
#define SNAP_BUF    (SNAP_BASE + 0x8000)

#define RF_TILE     2          /* tile 226/230: the ADC_A / DAC_A pair    */
#define DAC_NCO_MHZ 1000.0
#define ADC_NCO_MHZ -900.0
#define FS_MSPS     2457.6     /* I-sample rate after 2x decimation       */
#define N_BEATS     1024
#define N_SAMP      (N_BEATS * 8)

static XRFdc rfdc;
static struct metal_device *rfdc_dev = NULL;
static metal_phys_addr_t rfdc_phys;
static struct metal_device rfdc_metal_dev = {
    .name = NULL,
    .bus = NULL,
    .num_regions = 1,
    .regions = { {
        .virt = NULL,
        .physmap = &rfdc_phys,
        .size = 0x40000,
        .page_shift = (unsigned)(-1),
        .page_mask = (unsigned)(-1),
        .mem_flags = 0,
        .ops = { NULL },
    } },
    .node = { NULL },
    .irq_num = 0,
    .irq_info = NULL,
};

static int16_t samples[N_SAMP];

static int rfdc_init(void)
{
    struct metal_init_params init_param = METAL_INIT_DEFAULTS;
    if (metal_init(&init_param)) {
        xil_printf("metal_init failed\r\n");
        return XST_FAILURE;
    }

    XRFdc_Config *cfg = XRFdc_LookupConfig(XPAR_XRFDC_0_BASEADDR);
    if (cfg == NULL) {
        xil_printf("XRFdc_LookupConfig failed\r\n");
        return XST_FAILURE;
    }
    rfdc_phys = cfg->BaseAddr;
    rfdc_metal_dev.name = cfg->Name;
    rfdc_metal_dev.regions[0].virt = (void *)cfg->BaseAddr;
    rfdc_dev = &rfdc_metal_dev;
    if (XRFdc_RegisterMetal(&rfdc, 0, &rfdc_dev) != XRFDC_SUCCESS) {
        xil_printf("XRFdc_RegisterMetal failed\r\n");
        return XST_FAILURE;
    }
    if (XRFdc_CfgInitialize(&rfdc, cfg) != XRFDC_SUCCESS) {
        xil_printf("XRFdc_CfgInitialize failed\r\n");
        return XST_FAILURE;
    }
    return XST_SUCCESS;
}

/* Restart both tile-2 state machines and wait for "running" + PLL lock. */
static int rfdc_start_tiles(void)
{
    XRFdc_Reset(&rfdc, XRFDC_DAC_TILE, RF_TILE);
    XRFdc_Reset(&rfdc, XRFDC_ADC_TILE, RF_TILE);

    for (int tries = 0; tries < 100; tries++) {
        XRFdc_IPStatus ip;
        if (XRFdc_GetIPStatus(&rfdc, &ip) != XRFDC_SUCCESS)
            return XST_FAILURE;
        u32 dac_state = ip.DACTileStatus[RF_TILE].TileState;
        u32 adc_state = ip.ADCTileStatus[RF_TILE].TileState;
        if (dac_state == 15 && adc_state == 15) {
            xil_printf("  DAC tile %d state=15 PLL=%s, ADC tile %d state=15 PLL=%s\r\n",
                       RF_TILE, ip.DACTileStatus[RF_TILE].PLLState ? "locked" : "UNLOCKED",
                       RF_TILE, ip.ADCTileStatus[RF_TILE].PLLState ? "locked" : "UNLOCKED");
            return (ip.DACTileStatus[RF_TILE].PLLState &&
                    ip.ADCTileStatus[RF_TILE].PLLState) ? XST_SUCCESS : XST_FAILURE;
        }
        usleep(10000);
        if (tries == 99)
            xil_printf("  tiles stuck: DAC state=%lu ADC state=%lu (no sample clock?)\r\n",
                       (unsigned long)dac_state, (unsigned long)adc_state);
    }
    return XST_FAILURE;
}

/* Set a fine-mixer NCO on every enabled block of the tile. Dual- vs
 * quad-tile parts number their blocks differently (the ZU48DR's 5 GSPS
 * ADC tiles are dual) - probing IsBlockEnabled sidesteps the whole
 * question instead of hardcoding an ID that's right on one part. */
static int set_nco(u32 type, double freq_mhz, u32 mixer_mode)
{
    const char *name = (type == XRFDC_DAC_TILE) ? "DAC" : "ADC";
    int hits = 0;

    for (u32 blk = 0; blk < 4; blk++) {
        int en = (type == XRFDC_DAC_TILE)
                     ? XRFdc_IsDACBlockEnabled(&rfdc, RF_TILE, blk)
                     : XRFdc_IsADCBlockEnabled(&rfdc, RF_TILE, blk);
        if (!en)
            continue;

        XRFdc_Mixer_Settings mix;
        if (XRFdc_GetMixerSettings(&rfdc, type, RF_TILE, blk, &mix) != XRFDC_SUCCESS)
            return XST_FAILURE;
        mix.MixerType      = XRFDC_MIXER_TYPE_FINE;
        mix.MixerMode      = mixer_mode;
        mix.CoarseMixFreq  = XRFDC_COARSE_MIX_OFF;
        mix.Freq           = freq_mhz;
        mix.PhaseOffset    = 0.0;
        mix.FineMixerScale = XRFDC_MIXER_SCALE_1P0;
        mix.EventSource    = XRFDC_EVNT_SRC_TILE;
        if (XRFdc_SetMixerSettings(&rfdc, type, RF_TILE, blk, &mix) != XRFDC_SUCCESS) {
            xil_printf("  %s tile %d block %lu: SetMixerSettings FAILED\r\n",
                       name, RF_TILE, (unsigned long)blk);
            return XST_FAILURE;
        }
        XRFdc_UpdateEvent(&rfdc, type, RF_TILE, blk, XRFDC_EVENT_MIXER);
        xil_printf("  %s tile %d block %lu: NCO = %d MHz\r\n",
                   name, RF_TILE, (unsigned long)blk, (int)freq_mhz);
        hits++;
    }
    return hits ? XST_SUCCESS : XST_FAILURE;
}

static void capture(void)
{
    Xil_Out32(SNAP_CTRL, 1);
    while ((Xil_In32(SNAP_STATUS) & 1) == 0)
        ;   /* 1024 beats at 307.2 MHz: done in ~3.3 us */
    for (int b = 0; b < N_BEATS; b++) {
        for (int w = 0; w < 4; w++) {
            uint32_t v = Xil_In32(SNAP_BUF + b * 16 + w * 4);
            samples[b * 8 + w * 2]     = (int16_t)(v & 0xFFFF);
            samples[b * 8 + w * 2 + 1] = (int16_t)(v >> 16);
        }
    }
}

int main(void)
{
    xil_printf("\r\n=== module 22: RFDC intro (RFSoC4x2, bare metal) ===\r\n");

    uint32_t id = Xil_In32(SNAP_ID);
    xil_printf("axis_snap ID = 0x%08lx (%s)\r\n", (unsigned long)id,
               id == 0xACE00022 ? "ok" : "UNEXPECTED");

    xil_printf("\r\n-- 1. RF clock chain over PS SPI0 --\r\n");
    if (rfclk_program() != XST_SUCCESS) {
        xil_printf("FAIL: clock programming\r\n");
        return 1;
    }
    usleep(100000);   /* clocks settle before the tiles look for them */

    xil_printf("\r\n-- 2. RFDC init + tile start --\r\n");
    if (rfdc_init() != XST_SUCCESS) {
        xil_printf("FAIL: RFDC init\r\n");
        return 1;
    }
    if (rfdc_start_tiles() != XST_SUCCESS) {
        xil_printf("FAIL: tiles did not reach running/locked state\r\n");
        return 1;
    }

    xil_printf("\r\n-- 3. NCOs --\r\n");
    if (set_nco(XRFDC_DAC_TILE, DAC_NCO_MHZ, XRFDC_MIXER_MODE_C2R) != XST_SUCCESS ||
        set_nco(XRFDC_ADC_TILE, ADC_NCO_MHZ, XRFDC_MIXER_MODE_R2C) != XST_SUCCESS) {
        xil_printf("FAIL: mixer setup\r\n");
        return 1;
    }
    usleep(1000);

    xil_printf("\r\n-- 4. capture + measure --\r\n");
    capture();

    int16_t vmin = 32767, vmax = -32768;
    int64_t acc = 0;
    for (int i = 0; i < N_SAMP; i++) {
        if (samples[i] < vmin) vmin = samples[i];
        if (samples[i] > vmax) vmax = samples[i];
        acc += samples[i];
    }
    int32_t mean = (int32_t)(acc / N_SAMP);

    int crossings = 0;
    for (int i = 1; i < N_SAMP; i++) {
        int16_t a = samples[i - 1], b = samples[i];
        if ((a - mean < 0) != (b - mean < 0))
            crossings++;
    }
    /* f = (crossings/2) periods over N_SAMP/FS seconds */
    int freq_khz = (int)((int64_t)crossings * (int64_t)(FS_MSPS * 1000.0)
                         / (2 * (N_SAMP - 1)));

    xil_printf("min=%d max=%d mean=%ld peak-peak=%d\r\n",
               vmin, vmax, (long)mean, vmax - vmin);
    xil_printf("zero crossings=%d over %d samples at %d.%d MSPS\r\n",
               crossings, N_SAMP, (int)FS_MSPS, ((int)(FS_MSPS * 10)) % 10);
    xil_printf("measured ~= %d.%03d MHz (expect ~100 MHz)\r\n",
               freq_khz / 1000, freq_khz % 1000);

    /* a little ASCII scope: first 64 samples, one column each */
    xil_printf("\r\nfirst 64 samples:\r\n");
    for (int row = 7; row >= 0; row--) {
        char line[65];
        for (int i = 0; i < 64; i++) {
            int level = ((int)samples[i] + 32768) / 4096;   /* 0..15 */
            line[i] = (level / 2 == row) ? '*' : ' ';
        }
        line[64] = 0;
        xil_printf("|%s|\r\n", line);
    }

    int strong = (vmax - vmin) > 4000;
    int freq_ok = freq_khz > 90000 && freq_khz < 110000;
    if (strong && freq_ok)
        xil_printf("\r\nPASS: loopback tone at ~100 MHz\r\n");
    else if (!strong)
        xil_printf("\r\nFAIL: no signal - is DAC_A cabled to ADC_A?\r\n");
    else
        xil_printf("\r\nFAIL: signal present but wrong frequency\r\n");

    while (1)
        __asm__ volatile("wfi");
    return 0;
}
