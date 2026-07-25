# 02 - Arithmetic circuits

**Goal:** build addition up from a single bit to a parameterized adder using
`generate`, look at *why* a faster adder structure exists (carry-lookahead)
and prove it's equivalent rather than just asserting it, then compose
adders and comparators into a small ALU.

## The building blocks (`hdl/`)

| Module | What it does |
|---|---|
| `full_adder.v` | one bit of addition: `sum`, `cout` from `a`, `b`, `cin` |
| `ripple_carry_adder.v` | WIDTH-bit adder, `generate`-instantiates WIDTH `full_adder`s, carry chained through |
| `cla_adder4.v` | fixed 4-bit carry-lookahead adder - same function as ripple, different (parallel) carry structure |
| `comparator.v` | behavioral `==`/`<`/`>` for two WIDTH-bit numbers |
| `comparator_eq_bitwise.v` | the same equality check, built bit-by-bit with a second `generate` example + a reduction operator |
| `alu.v` | ADD/SUB/AND/OR, composing `ripple_carry_adder` rather than reimplementing addition |

### `generate`/`genvar`: turning one module into an array of them

`ripple_carry_adder` is the first place this repo needs the same small
circuit repeated a parameterized number of times - hand-instantiating
`full_adder` sixteen times for a 16-bit adder (and again, differently, for
an 8-bit one) doesn't scale. A `generate ... for (genvar i = 0; ...) ...
endgenerate` block does that instantiation at elaboration time instead,
parameterized by `WIDTH`. Two things worth internalizing from this module
specifically:

- **Name your generate blocks** (`begin : bit_adders`, not a bare `begin`).
  An unnamed block gets an auto-generated name that's painful to find again
  once you're looking at synthesized hierarchy in the Vivado GUI or writing
  a hierarchical constraint against a specific bit-slice later.
- `generate` isn't only for instantiating sub-modules - `comparator_eq_bitwise`
  uses one to build an array of per-bit XNOR results (`assign` inside the
  loop, no sub-module at all), then combines them with a **reduction
  operator** (`&bit_eq` - AND every bit of the vector together, true only if
  all of them are). Reduction operators (`&`, `|`, `^` applied to a whole
  vector as a unary prefix) are worth recognizing on sight; they show up
  constantly once you're past toy examples.

### Ripple carry vs. carry-lookahead - made concrete, not just asserted

`ripple_carry_adder`'s carry chain means bit `WIDTH-1`'s sum can't be
correct until every earlier carry has rippled through - the delay through
the whole adder grows with `WIDTH`. `cla_adder4.v` computes every carry bit
directly from `a`/`b`/`cin` using propagate/generate equations (see its
header comment for the derivation), so in principle every carry bit is
available in parallel rather than one after another.

`sim/tb_cla_adder4.v` doesn't just check `cla_adder4` against arithmetic -
it instantiates *both* `cla_adder4` and `ripple_carry_adder#(.WIDTH(4))` in
the same testbench, feeds them identical inputs, and checks their outputs
match on all 512 combinations. That's the concrete version of "these are
structurally different but functionally identical," and it's also why there
isn't a separate `cla_top` hardware demo in this module: on an LED, a
correct CLA adder is indistinguishable from a correct ripple adder - the
difference is in propagation delay, which is a timing-report/simulation
question, not something 4 LEDs can show you. (`cla_adder4` also isn't
parameterized like the others - see its header comment for why that's a
deliberate choice, not an oversight.)

## Simulation

```sh
make SIM_TOP=tb_full_adder sim
make SIM_TOP=tb_ripple_carry_adder sim
make SIM_TOP=tb_cla_adder4 sim
make SIM_TOP=tb_comparator sim
make SIM_TOP=tb_comparator_eq_bitwise sim
make SIM_TOP=tb_alu sim
make sim-all                              # all six, stops at first failure
```

All six are exhaustive over their (small) input spaces: 8, 512, 512, 256,
256, and 1024 cases respectively.

## Hardware demos

All share the `sw[3:0]`/`led[3:0]` interface (constraints copied unchanged
from module 01, same reason as last time). Every demo here treats `sw[1:0]`
as one 2-bit operand and `sw[3:2]` as the other - only 4 switches exist, and
`WIDTH=2` is what fits alongside a fixed opcode for the ALU demos below.

```sh
make TOP=adder_top      BOARD=nexys4 bitstream    # (adder_top is the default TOP)
make TOP=comparator_top BOARD=nexys4 bitstream
make TOP=alu_add_top    BOARD=nexys4 bitstream
make TOP=alu_sub_top    BOARD=nexys4 bitstream
make TOP=alu_and_top    BOARD=nexys4 bitstream
make TOP=alu_or_top     BOARD=nexys4 bitstream
make program
```

The four `alu_*_top` demos each hardwire a different opcode into the same
underlying `alu` module rather than exposing an opcode switch - there's no
switch left over once two 2-bit operands are wired up. What to try:

- **`adder_top`**: `sw = 4'b1111` (a=3, b=3) -> `led` reads carry=1, sum=2
  (3+3=6=`0b110`).
- **`alu_sub_top`**: `sw[1:0]=1` (a=1), `sw[3:2]=2` (b=2) -> `led[1:0]` reads
  3 (1-2 = -1 = `2'b11` in two's complement), `led[2]` (cout) reads **0** -
  that's the borrow indicator, not a plain carry.
- **`comparator_top`**: set both operands equal and confirm only `led[0]`
  (eq) lights up; make `a` bigger and confirm only `led[2]` (gt) does.

## Board status

All six designs are simulation-verified (`make sim-all` - see above). Real
hardware bitstream builds hit a recurring Vivado licensing error
(`ERROR: ... a valid license was not found`, the same node-locked-license
issue noted in `CLAUDE.md`/`docs/build_system.md`) partway through this
module and haven't all been confirmed on real hardware yet.

| Board | Status |
|---|---|
| nexys4 | simulation-verified; hardware build pending (blocked by Vivado licensing) |
| rfsoc4x2 | simulation-verified; hardware build not yet attempted |
| blackboard | simulation-verified; hardware build not yet attempted |
