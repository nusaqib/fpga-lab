/* LLRF bring-up: the real hardware walk-through of what sim/tb_llrf_loop
 * proves in simulation - against the SMA loopback "cavity" (DAC_A ->
 * cable -> ADC_A: pure gain and phase, no resonance; a real cavity or
 * cavity emulator is roadmap P5).
 *
 * Sequence (each step prints its evidence):
 *   1. RF clocks (module 22's LMK/LMX programming) + RFDC tiles up,
 *      both NCOs at f_RF = 500 MHz.
 *   2. IDs of llrf_core and both wave_snaps.
 *   3. Open loop: feedforward drive, read the raw loop response.
 *   4. Loop-phase auto-calibration: set the rotation to the conjugate
 *      of the open-loop response so the loop sees it on the +I axis.
 *   5. Closed loop, CW: setpoint at the calibrated amplitude, watch
 *      MEAS land on SP with feedback on.
 *   6. Pulsed: 1 ms period, 100 us pulse, triggered captures armed;
 *      freeze and dump the pulse edges from both buffers.
 */
#include <stdint.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xstatus.h"
#include "sleep.h"
#include "metal/sys.h"
#include "xrfdc.h"
#include "rfclk.h"
#include "llrf_regs.h"

#define RF_TILE   2
#define F_RF_MHZ  500.0

static XRFdc rfdc;
static struct metal_device *rfdc_dev;
static metal_phys_addr_t rfdc_phys;
static struct metal_device rfdc_metal_dev = {
    .name = NULL, .bus = NULL, .num_regions = 1,
    .regions = { { .virt = NULL, .physmap = &rfdc_phys, .size = 0x40000,
                   .page_shift = (unsigned)(-1), .page_mask = (unsigned)(-1),
                   .mem_flags = 0, .ops = { NULL } } },
    .node = { NULL }, .irq_num = 0, .irq_info = NULL,
};

/* ---------- RFDC plumbing (module 22/23/24 recipe) ---------- */

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
            m.Freq = F_RF_MHZ;
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
            m.Freq = -F_RF_MHZ;
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

/* ---------- helpers ---------- */

static inline void wr(uint32_t off, uint32_t v) { Xil_Out32(LLRF_BASE + off, v); }
static inline uint32_t rd(uint32_t off)         { return Xil_In32(LLRF_BASE + off); }
static inline int16_t rd16(uint32_t off)        { return (int16_t)rd(off); }

static uint32_t isqrt32(uint32_t x)
{
    uint32_t r = 0, bit = 1u << 30;
    while (bit > x) bit >>= 2;
    while (bit) {
        if (x >= r + bit) { x -= r + bit; r = (r >> 1) + bit; }
        else              { r >>= 1; }
        bit >>= 2;
    }
    return r;
}

/* ---------- bring-up ---------- */

int main(void)
{
    xil_printf("\r\n== LLRF v0.1 bring-up (f_RF = 500 MHz, SMA loopback) ==\r\n");

    if (rfclk_program() != XST_SUCCESS) {
        xil_printf("FAIL: RF clock chain\r\n"); return 1;
    }
    xil_printf("LMK04828 + 2x LMX2594 programmed\r\n");
    if (rfdc_init() != XST_SUCCESS || rfdc_start_tiles() != XST_SUCCESS) {
        xil_printf("FAIL: RFDC init/tiles\r\n"); return 1;
    }
    if (set_mixers() != XST_SUCCESS) {
        xil_printf("FAIL: mixers\r\n"); return 1;
    }
    xil_printf("tile %d up, NCOs at +/-%d MHz\r\n", RF_TILE, (int)F_RF_MHZ);

    /* ---- 2: IDs ---- */
    xil_printf("llrf_core ID  %08x (want 11F00001)\r\n", rd(LLRF_ID));
    xil_printf("snap_adc  ID  %08x (want ACE011F1)\r\n",
               Xil_In32(SNAP_ADC_BASE + SNAP_ID));
    xil_printf("snap_dac  ID  %08x (want ACE011F2)\r\n",
               Xil_In32(SNAP_DAC_BASE + SNAP_ID));
    if (rd(LLRF_ID) != 0x11F00001) return 1;

    /* ---- 3: open loop ---- */
    wr(LLRF_DECIM, 8);              /* 307.2M / 256 = 1.2 MHz strobe   */
    wr(LLRF_LIM, 30000);
    wr(LLRF_ROT_C, 32767); wr(LLRF_ROT_S, 0);
    wr(LLRF_KP, 0); wr(LLRF_KI, 0);
    wr(LLRF_FF_I, 8000); wr(LLRF_FF_Q, 0);
    wr(LLRF_CTRL, LLRF_CTRL_RUN);   /* CW, feedback off */
    usleep(100000);
    int32_t oi = rd16(LLRF_RAW_I), oq = rd16(LLRF_RAW_Q);
    xil_printf("open loop: drive (8000,0) -> raw (%d,%d)\r\n", oi, oq);

    uint32_t mag = isqrt32((uint32_t)(oi * oi + oq * oq));
    if (mag < 100) {
        xil_printf("loop response too small - SMA cable DAC_A->ADC_A connected?\r\n");
        xil_printf("(continuing; loop steps below will not converge)\r\n");
        mag = 100;
    }

    /* ---- 4: loop-phase auto-cal: rotate response onto +I ---- */
    int32_t rc = (int32_t)(oi * 32767) / (int32_t)mag;
    int32_t rs = -(int32_t)(oq * 32767) / (int32_t)mag;
    wr(LLRF_ROT_C, (uint32_t)rc & 0xFFFF);
    wr(LLRF_ROT_S, (uint32_t)rs & 0xFFFF);
    usleep(10000);
    xil_printf("rot=(%d,%d): meas (%d,%d) - Q should be ~0\r\n",
               rc, rs, rd16(LLRF_MEAS_I), rd16(LLRF_MEAS_Q));

    /* ---- 5: closed loop, CW ---- */
    wr(LLRF_SP_I, mag); wr(LLRF_SP_Q, 0);
    wr(LLRF_KP, 8192);              /* 0.25 */
    wr(LLRF_KI, 1638);              /* 0.05 per strobe */
    wr(LLRF_CTRL, LLRF_CTRL_RUN | LLRF_CTRL_FB);
    usleep(100000);
    xil_printf("closed CW: sp (%d,0) -> meas (%d,%d), drive (%d,%d), STATUS %08x\r\n",
               (int)mag, rd16(LLRF_MEAS_I), rd16(LLRF_MEAS_Q),
               rd16(LLRF_DRV_I), rd16(LLRF_DRV_Q), rd(LLRF_STATUS));

    /* ---- 6: pulsed with triggered captures ---- */
    wr(LLRF_CTRL, 0);
    wr(LLRF_PERIOD, 307200);        /* 1 ms   */
    wr(LLRF_DELAY, 256);            /* 0.83 us - the 1024-beat capture
                                     * window (3.3 us) must contain the
                                     * gate edge and the start of fill  */
    wr(LLRF_WIDTH, 30720);          /* 100 us */
    wr(LLRF_FB_DLY, 9216);          /* 30 us: skip the fill        */
    wr(LLRF_FB_WID, 24576);         /* to the end of the flat top  */
    Xil_Out32(SNAP_ADC_BASE + SNAP_CTRL, 2);   /* arm on pulse trigger */
    Xil_Out32(SNAP_DAC_BASE + SNAP_CTRL, 2);
    wr(LLRF_CTRL, LLRF_CTRL_RUN | LLRF_CTRL_PULSED | LLRF_CTRL_FB);
    usleep(500000);                 /* ~500 pulses */
    Xil_Out32(SNAP_ADC_BASE + SNAP_CTRL, 0);   /* freeze the last one */
    Xil_Out32(SNAP_DAC_BASE + SNAP_CTRL, 0);
    usleep(10000);
    xil_printf("pulsed: meas (%d,%d) in-window sample, STATUS %08x\r\n",
               rd16(LLRF_MEAS_I), rd16(LLRF_MEAS_Q), rd(LLRF_STATUS));
    xil_printf("snap_adc STATUS %08x, snap_dac STATUS %08x (want b0 done)\r\n",
               Xil_In32(SNAP_ADC_BASE + SNAP_STATUS),
               Xil_In32(SNAP_DAC_BASE + SNAP_STATUS));

    /* capture starts at the pulse trigger; the first DELAY beats are
     * pre-pulse (must read 0 on the dac buffer), then the gate opens.
     * (both captures: 32-byte beats; dac lane 0 = {Q,I}.) */
    xil_printf("dac drive around the gate edge (beat: I,Q):\r\n");
    for (int b = 254; b < 260; b++) {
        uint32_t w0 = Xil_In32(SNAP_DAC_BASE + SNAP_BUF + b * 32);
        xil_printf("  %d: %d, %d\r\n", b, (int16_t)(w0 & 0xFFFF),
                   (int16_t)(w0 >> 16));
    }
    xil_printf("adc probe at pulse edge + fill (beat: I0,Q0):\r\n");
    for (int b = 254; b < 266; b += 2) {
        uint32_t wi = Xil_In32(SNAP_ADC_BASE + SNAP_BUF + b * 32);
        uint32_t wq = Xil_In32(SNAP_ADC_BASE + SNAP_BUF + b * 32 + 16);
        xil_printf("  %d: %d, %d\r\n", b, (int16_t)(wi & 0xFFFF),
                   (int16_t)(wq & 0xFFFF));
    }

    xil_printf("== bring-up sequence complete ==\r\n");
    return 0;
}
