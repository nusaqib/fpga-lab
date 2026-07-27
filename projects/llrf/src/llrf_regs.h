#ifndef LLRF_REGS_H
#define LLRF_REGS_H

/* Register map of hdl/llrf_core.v and hdl/wave_snap.v - keep in sync
 * with DESIGN.md (the authoritative table) and the RTL. */

#ifdef XPAR_LLRF_CORE_0_BASEADDR
#define LLRF_BASE XPAR_LLRF_CORE_0_BASEADDR
#else
#define LLRF_BASE 0xA0110000UL
#endif
#ifdef XPAR_SNAP_ADC_BASEADDR
#define SNAP_ADC_BASE XPAR_SNAP_ADC_BASEADDR
#else
#define SNAP_ADC_BASE 0xA0100000UL
#endif
#ifdef XPAR_SNAP_DAC_BASEADDR
#define SNAP_DAC_BASE XPAR_SNAP_DAC_BASEADDR
#else
#define SNAP_DAC_BASE 0xA0120000UL
#endif

#define LLRF_ID      0x00   /* RO 0x11F00001 */
#define LLRF_CTRL    0x04   /* b0 run, b1 pulsed, b2 fb_en, b3 ext_trig */
#define LLRF_STATUS  0x08   /* b0 rf_gate, b1 fb_gate, b8/b9 sat sticky */
#define LLRF_DECIM   0x0C
#define LLRF_SP_I    0x10
#define LLRF_SP_Q    0x14
#define LLRF_KP      0x18
#define LLRF_KI      0x1C
#define LLRF_FF_I    0x20
#define LLRF_FF_Q    0x24
#define LLRF_ROT_C   0x28
#define LLRF_ROT_S   0x2C
#define LLRF_LIM     0x30
#define LLRF_PERIOD  0x34
#define LLRF_DELAY   0x38
#define LLRF_WIDTH   0x3C
#define LLRF_FB_DLY  0x40
#define LLRF_FB_WID  0x44
#define LLRF_MEAS_I  0x48
#define LLRF_MEAS_Q  0x4C
#define LLRF_DRV_I   0x50
#define LLRF_DRV_Q   0x54
#define LLRF_RAW_I   0x58
#define LLRF_RAW_Q   0x5C

#define LLRF_CTRL_RUN     (1u << 0)
#define LLRF_CTRL_PULSED  (1u << 1)
#define LLRF_CTRL_FB      (1u << 2)
#define LLRF_CTRL_EXTTRIG (1u << 3)

/* wave_snap */
#define SNAP_ID      0x00   /* 0xACE011F1 (adc) / 0xACE011F2 (dac) */
#define SNAP_CTRL    0x04   /* b0 soft arm, b1 arm on pulse trigger */
#define SNAP_STATUS  0x08   /* b0 done, b1 armed, b2 trig_en */
#define SNAP_DEPTH   0x0C
#define SNAP_BUF     0x8000

#endif
