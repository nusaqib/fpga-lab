# LLRF - design document

A direct-sampling digital low-level RF system on the RFSoC4x2. This file is
the project's anchor: architecture, number formats, rates, the register
map, and the phase roadmap. `README.md` is the shorter "what is this /
how do I build it" view.

## Goals (from the project brief)

1. **Direct RF sampling** - no analog up/down conversion boards; cavity
   probe straight into the ADC, drive straight out of the DAC. The RFSoC's
   converters and NCOs do all frequency translation digitally.
2. **Frequency-flexible, 500 MHz first.** The carrier is set purely by the
   RFDC NCOs (software), so any f_RF inside the converters' Nyquist range
   works. 500 MHz sits comfortably in the first Nyquist zone of the
   4.9152 GSPS configuration we already run (Nyquist edge 2457.6 MHz).
3. **Waveform capture for diagnostics** - BRAM recorders on both the ADC
   (cavity probe) and DAC (drive) streams, hardware-triggerable at the
   pulse start so every pulse can be inspected sample by sample.
4. **Pulsed mode** - a timing generator producing an RF gate and a
   separate feedback-window gate, from an internal period counter or an
   external trigger input; CW is the degenerate case (gates always open).
5. **Deployable beyond one bench** - clean register interface, scripted
   builds, software from bare metal (bring-up) to Linux/Python (Tier 6
   infrastructure); chassis and packaging come after firmware matures.

## Why this can lean on the curriculum

Everything below the LLRF logic is already proven in this repo:

- RF clock chain (LMK04828 + 2x LMX2594, vendored PYNQ register sets),
  RFDC bring-up, NCO/mixer control: modules 22-23.
- The exact converter configuration (tile 2: DAC_A/vout20, ADC_A/vin2_23,
  4.9152 GSPS, fine mixers, fabric streams at 307.2 MHz): module 24's
  `sdr_sys` block design, reused here nearly verbatim.
- BRAM stream capture: module 22/24's `axis_snap` lineage.
- AXI4-Lite register file: module 11/15's hand-written slave skeleton.
- Linux + UIO + Python operations: modules 16-18.

## Signal chain

```
                 f_RF (e.g. 500 MHz)             fabric, 307.2 MHz
 cavity probe --> [ADC 4.9152G] --> [fine mixer, NCO -f_RF] --> 2x dec
   --> 8 IQ pairs / beat  ................................. s_axis_adc
   --> [beat mean /8] --> [dec 2^N] --> [iq_rotate (loop phase)]
   --> meas I/Q  --> [PI ctrl I] [PI ctrl Q]  <-- setpoint I/Q
                        |            |        <-- feedforward I/Q
                        v            v            (+ rf/fb gates)
                   drive I/Q (clamped) --> [x4 replicate] . m_axis_dac
   --> [fine mixer, NCO +f_RF] --> [DAC 4.9152G] --> cavity drive

 [pulse_gen] --> rf_gate (drive on/off), fb_gate (integrator window),
                 trig (capture arm) - internal period or external trigger
 [wave_snap] x2 --> 1024-beat BRAM capture of ADC stream + DAC stream
```

## Rates and formats (all inherited from module 24's verified config)

| Point | Rate | Format |
|---|---|---|
| ADC sampling | 4915.2 MSPS | 14-bit in 16 |
| ADC baseband (after mixer + 2x dec) | 2457.6 Mcplx/s | 8 IQ pairs per 256-bit beat |
| Fabric clock | 307.2 MHz | everything below runs here |
| After beat mean | 307.2 Mcplx/s | one Q1.15 IQ pair per cycle |
| After 2^N decimator | 307.2/2^N Mcplx/s | N = 0..12; N=8 -> 1.2 MHz loop rate |
| PI controller | strobe at decimated rate | Q1.15 in/out, 34-bit integrator |
| DAC drive | held between strobes | 8 {Q,I} pairs per 256-bit beat, 2457.6 Mcplx/s |

Q1.15 everywhere at module boundaries; products are >>>15 with saturation.
The loop-phase rotator carries unit vectors (cos/sin as Q1.15 written by
software) rather than angles - no CORDIC in the loop; amplitude/phase for
displays are computed in software from I/Q.

f_RF never appears in the fabric: both NCOs are set by software through
the RFDC driver, which is what makes the system frequency-flexible.

## Control law (v0.1)

Per axis (I and Q independently, after the loop-phase rotation):

```
e     = setpoint - meas                    (on each decimator strobe)
p     = (Kp * e) >>> 15
acc  += (Ki * e)          when fb_en && fb_gate; acc clamped to +/-(LIM<<15)
u     = sat(p + (acc >>> 15) + ff, +/-LIM)
drive = rf_gate ? u : 0
```

The integrator clamp is the anti-windup (simple, inspectable); `fb_gate`
freezes the integrator outside the useful part of a pulse so the loop
doesn't integrate on an empty cavity; `run=0` clears the accumulator.
Feedforward `ff` is a static I/Q in v0.1 - a per-pulse feedforward table
is a roadmap item.

## Register map (AXI4-Lite, 32-bit, byte offsets)

| Off | Name | RW | Meaning |
|---|---|---|---|
| 0x00 | ID | RO | 0x11F0_0001 (LLRF, v0.1) |
| 0x04 | CTRL | RW | b0 run, b1 mode (0 CW / 1 pulsed), b2 fb_en, b3 ext_trig_en |
| 0x08 | STATUS | RO | b0 rf_gate, b1 fb_gate live; b8/b9 sticky I/Q drive-sat flags (cleared by CTRL write) |
| 0x0C | DECIM | RW | N, log2 post-mean decimation (clamped to 2..12 - the PI engine takes 3 cycles per strobe) |
| 0x10 | SP_I | RW | setpoint I, Q1.15 |
| 0x14 | SP_Q | RW | setpoint Q |
| 0x18 | KP | RW | proportional gain, Q1.15 |
| 0x1C | KI | RW | integral gain per strobe, Q1.15 |
| 0x20 | FF_I | RW | feedforward drive I |
| 0x24 | FF_Q | RW | feedforward drive Q |
| 0x28 | ROT_C | RW | loop-phase rotation cos, Q1.15 |
| 0x2C | ROT_S | RW | loop-phase rotation sin |
| 0x30 | LIM | RW | per-axis drive clamp (positive Q1.15) |
| 0x34 | PERIOD | RW | pulse period, fabric cycles |
| 0x38 | DELAY | RW | rf_gate delay from trigger, cycles |
| 0x3C | WIDTH | RW | rf_gate width, cycles |
| 0x40 | FB_DLY | RW | fb_gate delay from trigger, cycles |
| 0x44 | FB_WID | RW | fb_gate width, cycles |
| 0x48 | MEAS_I | RO | live measurement after rotation (loop's view) |
| 0x4C | MEAS_Q | RO | |
| 0x50 | DRV_I | RO | current drive |
| 0x54 | DRV_Q | RO | |
| 0x58 | RAW_I | RO | decimated measurement before rotation |
| 0x5C | RAW_Q | RO | |

Capture buffers are separate `wave_snap` instances (one on the ADC beat
stream, one on the DAC beat stream) with their own small map, evolved
from module 24's `axis_snap_iq`: ID 0xACE0_11F1, CTRL b0 soft-arm /
b1 arm-on-hardware-trigger, STATUS, DEPTH, buffer at +0x8000.

## Roadmap

- **P0** scaffold + this document. (done)
- **P1** core DSP in RTL, each block + the closed loop simulation-verified
  against a mock cavity (first-order lag + rotation + gain plant).
  (RTL + testbenches written; sim runs pending license recovery)
- **P2** block design: module 24's RFDC skeleton + `llrf_core` + two
  `wave_snap`s; bitstream + XSA. (written; build pending license)
- **P3** bare-metal bring-up software (clocks -> NCOs at 500 MHz -> drive
  a setpoint into the SMA loopback, capture pulses). (`src/main.c`
  written; ELF pending the P2 XSA)
- **P4** Linux operations: UIO/Python tooling from module 18 pointed at
  this register map; capture readout + pulse plots from Python; then
  remote operations (EPICS IOC or similar) for "used all over the world".
- **P5** hardware validation: SMA-loopback closed loop first (the "cavity"
  is a cable - pure gain/phase, no resonance), then a real cavity or a
  cavity emulator; measure loop gain/phase margins properly.
- **P6** productization: per-pulse feedforward table, amplitude/phase
  display path, interlock inputs, multi-cavity scaling (three more ADC
  pairs are unused), chassis.

## Honest limits of v0.1

- One cavity channel (ADC_A/DAC_A), one PI loop in IQ. No klystron
  linearization, no beam-loading feedforward table yet.
- The plant between DAC and ADC (amplifier + cavity) is assumed
  slow compared to the decimated loop rate; there is no loop-delay
  compensation beyond what the PI gains absorb.
- Pulse timing counts fabric cycles (3.255 ns granularity); no
  sub-cycle trigger alignment yet.
- Interlocks are not implemented - do not connect this to a real
  high-power system until they are.
