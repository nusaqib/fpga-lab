# LLRF - direct-sampling digital low-level RF (RFSoC4x2)

A digital LLRF system: the cavity probe goes straight into an RFSoC ADC,
the cavity drive comes straight out of a DAC, and everything between -
downconversion, filtering, the amplitude/phase (I/Q) feedback loop, pulse
timing, and waveform diagnostics - is fabric logic behind one register
map. Carrier frequency is a software setting (RFDC NCOs); first target
is 500 MHz. **Read `DESIGN.md`** for the architecture, register map, and
roadmap - this file is the build/run view.

Long-term intent: mature the firmware/software here until the system is
deployable anywhere (chassis and packaging come after that).

## Layout

```
DESIGN.md          architecture + register map + roadmap (start here)
hdl/               the LLRF fabric: llrf_core (regs + DSP + timing),
                   iq_beat_mean, dec_pow2, iq_rotate, pi_ctrl,
                   pulse_gen, wave_snap (diagnostics capture)
bd/llrf_sys.tcl    module 24's RFDC plumbing around llrf_core
sim/               tb_llrf_dsp (units), tb_pulse_gen (timing),
                   tb_llrf_loop (CLOSED LOOP against a mock cavity,
                   through the real register interface)
src/               bare-metal bring-up (rfclk from module 22 verbatim,
                   llrf_regs.h, main.c walk-through)
constraints/       LEDs only - RF I/O uses dedicated package pins
```

## Build & verify

```sh
make sim-all             # all three testbenches (no hardware needed)
make bitstream xsa elf   # rfsoc4x2 hardware + bring-up ELF
```

The one testbench to read is `sim/tb_llrf_loop.v`: it wraps `llrf_core`
around a behavioral plant (gain 0.5, +30 deg rotation, first-order fill,
static offset), calibrates the loop rotation the way the real software
does, and demands the measured I/Q land on the setpoint - CW first, then
across pulses with gated feedback and hardware-triggered capture.

## Bench bring-up (SMA loopback first)

Cable DAC_A -> ADC_A (the Tier 8 cable), then run the ELF: it programs
the RF clocks, brings the tiles up with NCOs at +/-500 MHz, checks IDs,
measures the open-loop response, auto-calibrates the loop phase, closes
the loop in CW, then runs 1 ms / 100 us pulses with both wave_snaps
triggering on the pulse and dumps the gate edges from the captures.
The cable is a zero-order "cavity" (gain and phase, no resonance) -
enough to validate every part of the system except cavity dynamics.

## Status

- [x] P0: design doc.
- [~] P1: all DSP + timing + capture RTL and the three testbenches
      written; **sim runs blocked on a Vivado license outage** (the
      recurring HOSTID/MAC mismatch - the license is tied to a USB
      Ethernet adapter that is currently absent). Verification resumes
      the moment the license is back; do not trust the loop until then.
- [~] P2: block design + constraints written; bitstream blocked on the
      same license.
- [~] P3: bring-up main.c written; ELF build needs the XSA from P2.
- [ ] Bench: SMA-loopback bring-up run (needs the board + cable).
- [ ] P4+: Linux/Python operations, cavity emulator, interlocks - see
      DESIGN.md roadmap.

| Board | Status |
|---|---|
| rfsoc4x2 | primary target |
| blackboard / nexys4 | n/a - no RF data converters |
