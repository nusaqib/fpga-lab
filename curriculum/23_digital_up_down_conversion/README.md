# 23 - Digital up/down conversion (RFSoC4x2, bare metal)

**Goal:** module 22 proved the RF path works; this module proves it's a
*radio*. Same bitstream, same SMA loopback (DAC_A -> ADC_A), same 1 GHz
carrier - and then the receiver is retuned, remixed and re-rated purely
from software. One bitstream, many radios: DUC/DDC lives in the tiles'
runtime registers, not in the fabric.

## The three experiments (`src/main.c`)

**A. Fine NCO sweep - what "tuning" actually is.** The ADC's fine mixer
multiplies incoming samples by `e^(-j*2*pi*f_nco*t)` from a 48-bit NCO.
Stepping `f_nco` from -800 to -1200 MHz while the carrier sits at
1000 MHz walks the baseband beat through |1000 - |f_nco|| MHz, measured
by zero-crossing count and checked row by row:

```
NCO MHz | expect kHz | measured kHz | pk-pk | verdict
   -800 |     200000 |       ~200e3 |  ...  | ok
   -900 |     100000 |       ~100e3 |  ...  | ok
  -1050 |      50000 |        ~50e3 |  ...  | ok   <- image: |1000-1050|
```

Note the fold at -1050/-1100: the beat comes back *up* - negative
baseband frequencies look identical in a single real component. (Module
24 uses I *and* Q, which is exactly how you tell -50 from +50 MHz.)

**B. Coarse mixer at fs/4 - the free mixer.** At exactly fs/4 the mixer
sequence `e^(-j*2*pi*n/4)` degenerates to `1, -j, -1, j` - no
multipliers, just sign/lane swaps, zero power, zero NCO. The catch:
only fs/2 and fs/4 exist. fs/4 = 1228.8 MHz here, so the 1 GHz carrier
lands at 228.8 MHz. The lesson is the trade: coarse = free but fixed,
fine = tunable but real hardware.

**C. Runtime decimation 2x -> 4x - rate is a setting, not a fact.**
`XRFdc_SetDecimationFactor` halves the output rate on a live datapath.
The captured tone "doubles" in apparent frequency if you keep using the
old sample rate in the math - then reads 100 MHz again once the
arithmetic knows the true rate. Same signal, same wire, different clock
bookkeeping: the classic DSP bug, demonstrated on purpose.

## Build & run

```sh
make bitstream xsa elf
make program
```

SMA cable DAC_A -> ADC_A, UART at 115200. Everything self-checks; the
final line is a single PASS/FAIL.

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | bitstream + xsa + elf build; bench run pending (SMA loopback) |
| nexys4 / blackboard | n/a - no RF data converters |
