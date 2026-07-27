# 22 - RF data converter intro (RFSoC4x2, bare metal)

**Goal:** make the RFSoC do the thing it exists for. A DAC tile transmits
a 1 GHz carrier out an SMA, an ADC tile digitizes it back in, and C code
on the A53 proves it - with **no operating system and no PYNQ**: every
layer that the PYNQ image hides (clock chips, tile state machines, NCOs)
is done by hand here, which is the lesson.

## The part nobody tells you about: the clock chain

A fresh RFSoC4x2 bitstream with a perfectly configured RFDC does
*nothing*. The RF tiles need a sample reference clock from two LMX2594
synthesizers, which in turn need a system reference from an LMK04828 -
three TI chips on the board that power up unprogrammed. The PYNQ image
programs them at boot (`xrfclk` package); bare metal, that's our job:

- PS **SPI0**, chip selects: CS0 = LMK04828, CS1 = LMX2594 (DAC tiles),
  CS2 = LMX2594 (ADC tiles) - topology from the board's device tree.
- Register values: TI TICS Pro exports vendored **verbatim** from the
  official RFSoC-PYNQ repo into `boards/rfsoc4x2/rfclk/` (the same rule
  as pin constraints: never hand-typed). `scripts/tics_to_header.py`
  turns them into `src/rfclk_regs.h`.
- Protocol (from `xrfclk.py`): LMK = 136 x 24-bit writes in file order.
  LMX = RESET on/off, 113 registers R112->R0, then R0 once more so the
  VCO calibrates from a stable state. All SPI mode 0, 24-bit MSB-first.

`src/rfclk.c` is the whole thing in ~100 lines of XSpiPs.

## Signal path (tile-2 pair = the DAC_A / ADC_A SMAs)

```
dc_source (fabric)          RFDC DAC tile 230 blk 0        SMA DAC_A
I=0.5FS, Q=0  ----128b----> fine mixer @ +1000 MHz  ----~~~~ 1 GHz ~~~~
constant forever            2x interp, 4.9152 GSPS              |
                                                          (SMA cable)
axis_snap (fabric)          RFDC ADC tile 226 (ADC_A)           |
BRAM, 1024 beats <--128b--- fine mixer @ -900 MHz   <---~~~~~~~~'
= 8192 I samples            2x decim, 4.9152 GSPS
@ 2457.6 MSPS
```

The transmitter has **zero DSP in the fabric**: `dc_source` is a constant.
DC baseband through a fine mixer *is* a pure carrier at the NCO frequency -
the synthesizer lives inside the converter tile. On the way back, the ADC
NCO at -900 MHz leaves the tone at 100 MHz, and `main.c` measures it by
counting zero crossings in the captured buffer. Every tile parameter
(sample rate, PLL refclk, mixer type, decimation) mirrors the official
PYNQ base overlay for this board - trimmed to the one tile pair.

`axis_snap` is this module's new reusable block: arm-over-AXI4-Lite,
record N stream beats to BRAM, read back over the same window. Unlike
module 12's `axis_capture` (counters + last beat), this stores the
actual waveform. It runs entirely on the ADC's 307.2 MHz stream clock;
SmartConnect owns the CDC from the PS.

## Build & run

```sh
make bitstream xsa elf     # BOARD defaults to rfsoc4x2
make program               # or program + run the ELF from Vitis/xsdb
```

Connect **DAC_A to ADC_A** with an SMA cable (hand-tight is fine at
1 GHz). UART (115200) walks through the sequence:

1. `rfclk:` three chips programmed over SPI0
2. tile state machines restarted, polled to state 15 (running) + PLL lock
3. NCOs set: DAC +1000 MHz (C2R), ADC -900 MHz (R2C)
4. capture + measurement: `PASS: loopback tone at ~100 MHz` and an ASCII
   scope of the first 64 samples

No cable -> step 4 reports "no signal" (and that's a meaningful test
too: the tiles still lock, proving the clock chain apart from the RF path).

## What to notice

- **Tile state 15**: `XRFdc_GetIPStatus` after reset shows the tile boot
  sequence stall (state 6-ish) when the sample clock is missing, and run
  to 15 the moment the LMX chips are programmed. That single number is
  the RFSoC's most important debugging signal.
- **Block numbering**: the ZU48DR's 5 GSPS ADC tiles are *dual* tiles -
  the driver numbers their blocks differently from quad tiles, so
  `main.c` probes `XRFdc_IsADCBlockEnabled` instead of hardcoding an ID.
- **Where's the XDC?** There isn't one (beyond bitstream policy). Every
  external port is a dedicated RF package pin; the wrapper is the top.

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | bitstream + xsa + elf build; hardware run pending (needs SMA cable on the bench) |
| nexys4 / blackboard | n/a - no RF data converters |
