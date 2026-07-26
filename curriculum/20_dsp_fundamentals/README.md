# 20 - DSP fundamentals

**Goal:** fixed-point arithmetic done honestly (formats, growth,
rounding, saturation), the DSP48 slice, and a 4-tap FIR filter built
twice - hand-written transposed-form Verilog and HLS C++ - bit-exact
against one shared reference model, then compared on real synthesis
results. The comparison produced a genuine surprise; see below.

## Fixed-point, concretely (Q1.15 everywhere)

- **Samples & coefficients**: Q1.15 - int16 `v` means `v/32768.0`,
  range [-1.0, +1.0). Coefficients {0.1, 0.4, 0.4, 0.1} become
  {3277, 13107, 13107, 3277} and sum to 32768 - exactly 1.0.
- **Products**: Q1.15 x Q1.15 = Q2.30 (32 bits).
- **Accumulation**: four Q2.30 terms need 2 growth bits -> Q4.30 in 34.
- **Output**: round-to-nearest (add half-LSB, arithmetic shift 15) then
  **saturate** to int16. The coefficients summing to exactly 1.0 is a
  planted lesson: a full-scale step drives the output to +1.0, which
  Q1.15 cannot represent - both implementations visibly clip to 0x7FFF
  instead of wrapping to -1.0, and both benches check exactly that.

Both implementations use explicit integer arithmetic so the Verilog, the
C++, and the reference model are provably bit-identical. (`ap_fixed<16,1,
AP_RND, AP_SAT>` expresses the same thing compactly once trusted - this
module makes you earn that trust once by hand.)

## Two lessons the tools taught while building this

**1. Powers of two are free.** The first draft used a 0.25x4 boxcar -
8192 = 2^13, and multiplying by a power of two is a wiring shift, so
synthesis used *zero multipliers* and the DSP48 lesson evaporated.
Coefficient choice changes the hardware, not just the frequency response.

**2. HLS found the symmetric-FIR optimization on its own.** The final
scoreboard (same function, bit-exact, both verified):

| | Hand RTL (`make ooc`) | HLS (`csynth` est.) |
|---|---|---|
| DSP48 | **4** | **2** |
| LUT / FF | 40 / 17 | 140 / 134 |
| Est. Fmax | (see timing.rpt) | 152 MHz |

I wrote the naive transposed form: four multipliers, one per tap. HLS
noticed the coefficients are symmetric and restructured to
`(x[n]+x[n-3])*3277 + (x[n-1]+x[n-2])*13107` - pre-adders, half the
multipliers. That's a standard trick (the DSP48's pre-adder exists for
exactly this), but nobody asked for it - the C described *what*, and the
scheduler chose *how*. The flip side: the HLS version spends ~3x the
fabric on handshake/control, and its structure is only discoverable by
reading reports. Neither column wins outright; knowing *why* each looks
the way it does is the module.

## Structure & verification

| Piece | What |
|---|---|
| `hdl/fir4_transposed.v` | transposed form (DSP48-cascade shape), `use_dsp`, explicit round/saturate function |
| `sim/tb_fir4_transposed.v` | impulse -> reads back scaled coefficients; saturating step; 500 random samples vs model |
| `hls/fir4_hls.cpp` | direct-form loop + UNROLL + `BIND_OP impl=dsp`, same quantization |
| `hls/tb_fir4_hls.cpp` | same three phases, deterministic LCG noise (cosim reruns it against generated RTL) |

```sh
make sim-all      # Verilog FIR vs reference model
make ooc          # out-of-context synth of the hand RTL: prints LUT/FF/DSP truth
make hls-csim && make hls-synth && make hls-cosim
```

`make ooc` is new build-system machinery (common/tcl/synth_ooc.tcl):
out-of-context synthesis for library blocks whose port counts exceed any
board's pins - no constraints, no project, just "what does this really
synthesize to", with a one-line `OOC RESULT:` summary.

## Board status

| Board | Status |
|---|---|
| nexys4 (default part) | sim + ooc + full HLS flow verified |
| blackboard / rfsoc4x2 | same flows via `BOARD=`; live-signal integration comes with module 21/24 |
