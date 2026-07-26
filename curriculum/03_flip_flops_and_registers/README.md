# 03 - Flip-flops and registers

**Goal:** the moment the curriculum crosses from combinational to
*sequential* logic - circuits with memory, driven by a clock. D flip-flop
variants and what genuinely distinguishes them, why `<=` (non-blocking)
matters, a register with clock enable, and a first honest look at
metastability. Also the first module whose hardware demo actually uses a
board's oscillator.

## The concept modules (`hdl/`)

| Module | What it teaches |
|---|---|
| `dff_variants.v` | async reset vs sync reset vs clock enable - three flavors of the same flop, and why the difference is hardware, not style |
| `register_en.v` | the WIDTH-bit enabled register: the most common sequential element in real designs |
| `pipeline2.v` | two flops back to back; the non-blocking (`<=`) lesson in its smallest real form |
| `sync2.v` | two-flop synchronizer + `ASYNC_REG`; the metastability introduction |
| `capture_top.v` | hardware demo composing sync2 + register_en |

### Non-blocking (`<=`) - the one rule to burn in now

Inside `pipeline2`'s single `always @(posedge clk)` block:

```verilog
stage1 <= d;
q      <= stage1;
```

Every `<=` samples its right-hand side from *before* the clock edge, and
all left-hand sides update together afterwards. So `q` gets the **old**
`stage1`, and the two statements build two flops in series - swap their
order and nothing changes. If these were blocking (`=`) assignments,
order would suddenly matter: `stage1 = d; q = stage1;` collapses both
statements into `q = d` (one flop, not two), silently. `tb_pipeline2.v` is
this lesson in executable form - it fails if the delay is anything other
than exactly two cycles.

Rule of thumb, good until you have a reason to break it: **`<=` in clocked
`always` blocks, `=` in combinational `always @*` blocks, never mix within
a block.**

### Reset flavors (dff_variants.v)

- **Async reset** (`always @(posedge clk or posedge rst)`) - takes effect
  immediately, clock running or not.
- **Sync reset** (`always @(posedge clk)`, rst checked inside) - takes
  effect only at a clock edge; synthesizes into the D-path logic rather
  than the flop's dedicated reset pin.
- **Clock enable** - not a reset at all, but the third thing that shows up
  in the same code position: "hold unless told." On FPGAs you slow logic
  down by enabling a fast clock less often, not by making slower clocks -
  module 04 builds exactly that.

`tb_dff_variants.v` drives all three side by side, including the one
scenario that distinguishes async from sync reset: assert reset *between*
clock edges and watch which flop responds immediately.

### Metastability and sync2

A flop needs its input stable in a small window around the clock edge
(setup/hold). A button press or a foreign-clock-domain signal can violate
that window, leaving the flop's output briefly *metastable* - genuinely
neither 0 nor 1. You can't prevent this; you give it a private flop to
happen in (`meta`), wait one clock, and use the settled second flop's
output. The `(* ASYNC_REG = "TRUE" *)` attributes tell Vivado to keep the
pair close together and never optimize them apart. Behavioral simulation
cannot show metastability (xsim's 4-value logic settles instantly - one of
simulation's honest limits); the testbench checks datapath correctness, and
the *reason* for sync2 stays a physical-world argument until module 08
digs deeper with CDC analysis.

## Simulation

```sh
make sim-all    # tb_capture_top, tb_dff_variants, tb_pipeline2, tb_register_en
```

New testbench machinery this module, in learning order: a generated clock
(`always #5 clk = ~clk`), stimulus on `negedge` so it's stable before the
`posedge` sample, and - in `tb_register_en` - the reference-model pattern
(drive random stimulus, update a behavioral model with the intended
semantics, compare every cycle). That pattern is the seed of every serious
verification environment you'll ever write; exhaustive truth-table loops
stopped scaling the moment time entered the picture.

## Hardware demo (`capture_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

Hold the button (Nexys4: BTNC center button; BlackBoard: BTN0), set the
switches, release - the LEDs freeze at the captured value and ignore the
switches until you hold the button again. The button passes through
`sync2` before touching the register enable; the constraints declare
`btn`/`sw` as false paths (asynchronous by nature, synchronized inside).

Note what this demo *doesn't* need: debouncing. A level enable just
re-captures a few extra times while the contacts bounce. The moment we
want "exactly one action per press" (module 04), bounce becomes a real
bug - that's the cliffhanger this module ends on.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready (uses 100MHz CLK100MHZ + BTNC) |
| blackboard | ready (uses 100MHz PL_CLK + BTN0) |
| rfsoc4x2 | deferred until Tier 5 - no free-running PL clock before Zynq PS bring-up (`boards/rfsoc4x2/docs/README.md`); intentionally no constraints file here |
