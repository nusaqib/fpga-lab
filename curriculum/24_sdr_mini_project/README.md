# 24 - Mini SDR: programmable transmitter, spectrum-analyzer receiver

**Goal:** Tier 8's capstone, and Tier 7's graduation exam. An HLS DDS
synthesizes a tunable complex baseband tone into the DAC; the received
I/Q pair is captured *simultaneously* and a 1024-point FFT on the A53
draws the spectrum over UART. TX frequency is a register write; RX is a
real spectrum with a real sign axis. One SMA cable = a working
software-defined radio, no OS anywhere.

```
A53 writes phase_inc ----------------------------.
                                                 v
dds_hls (HLS: 32b phase acc -> 1024-pt cos/sin ROMs, 4 cplx/beat)
  -> DAC fine mixer @ +1000 MHz -> DAC_A ~~~cable~~~ ADC_A
  -> ADC fine mixer @ -1000 MHz -> axis_combiner {Q,I} 256b
  -> axis_snap_iq (8 simultaneous complex samples/beat)
  -> A53: FFT -> ASCII spectrum + peak check, sign included
```

## What each piece teaches

- **`hls/dds_hls.cpp`** - the classic DDS structure (phase accumulator +
  table lookup) in ~30 lines, with an `s_axilite` register alongside
  `ap_ctrl_none` streaming: config registers and free-running kernels
  compose. `f = phase_inc / 2^32 * 1228.8 MHz`, signed - a negative
  increment is a negative frequency, and with I/Q that's a *different
  place on the spectrum*, not a mirror image.
- **`hdl/axis_snap_iq.v`** - module 22's recorder widened to 256 bits
  fed by an `axis_combiner` packing I and Q into ONE beat. Two separate
  recorders could never guarantee sample alignment; scrambled I/Q
  alignment scrambles the spectrum's phase. Sim: `tb_axis_snap_iq`.
- **`src/main.c`** - a 1024-point radix-2 FFT with **no libm**: the only
  trig constants an FFT actually needs are cos/sin(2*pi/2^s), eleven
  literals; every other twiddle falls out of the rotation recurrence
  (verified bit-for-bit against a host build with synthetic tones before
  first hardware run).
- **Sign calibration** - whether the spectrum comes out normal or
  conjugated depends on the DAC/ADC mixer sign conventions. The program
  *measures* it (sends +240 MHz, looks where it lands) instead of
  assuming, then holds every later check to that orientation.

## The payoff vs module 23

Module 23's single-component capture couldn't tell +50 MHz from
-50 MHz (the NCO sweep folded). Here the tone sweep is
{+240, -240, +480, -720, +96} MHz and the verdict requires the peak on
the correct **side** of DC. That asymmetry - visible only with I and Q -
is the entire reason radios are complex-valued.

## Build & run

```sh
make hls-csim          # DDS: amplitude/frequency/quadrature checks
make bitstream xsa elf # packages the HLS IP first, automatically
make program
```

SMA: DAC_A -> ADC_A. UART 115200 shows the calibration line, the ASCII
spectrum for the +240 MHz tone, the sweep table, and one final
PASS/FAIL.

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | bitstream + xsa + elf build; bench run pending (SMA loopback) |
| nexys4 / blackboard | n/a - no RF data converters |
