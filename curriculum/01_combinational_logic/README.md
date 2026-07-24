# 01 - Combinational logic

**Goal:** the basic building blocks of combinational logic - gates, a
multiplexer, a decoder, a priority encoder - written in Verilog two
different ways (`assign` and procedural `always @*`), each one verified by
an actual testbench before ever touching Vivado's synthesis flow.

## The four concept modules (`hdl/`)

| Module | Style | What it does |
|---|---|---|
| `logic_gates.v` | `assign` (dataflow) | AND/OR/XOR/NAND of two inputs |
| `mux4to1.v` | `always @*` + `case` | routes one of 4 data inputs to the output based on a 2-bit select |
| `decoder2to4.v` | `always @*` + `case` | turns a 2-bit address into a one-hot 4-bit output |
| `priority_encoder4to2.v` | `always @*` + if/else chain | turns a 4-bit request vector into the index of the *highest-priority* asserted bit |

### `assign` vs `always @*`

`logic_gates` is written entirely with `assign` statements - each output is
one continuous expression, always recomputed the instant an input changes.
Everything else here uses `always @*` with a `case` or if/else chain
instead. Both styles produce pure combinational logic (no clock, no memory,
no `<=`) - the difference is expressiveness: try writing the priority
encoder's "first asserted bit wins" logic as a single `assign` expression
and notice how much more awkward it gets past a couple of inputs. `always
@*` (or `always_comb` in SystemVerilog) is how essentially all non-trivial
combinational logic gets written in practice; `assign` stays the right
choice for genuinely simple expressions like the gates here.

One thing to internalize about `decoder2to4`: it includes a `default` case
even though `in`'s 2 bits already cover every value 0-3. That's
deliberate - an incomplete case list (or an `if` with no matching `else`)
inside an `always @*` block is exactly how you accidentally infer a latch
instead of combinational logic, because the simulator/synthesizer has to
assume the output "remembers" its old value in the uncovered case. Get in
the habit of covering every case explicitly now, before latches become a
real bug to chase in a bigger design.

## Simulation - the first testbench

Every concept module has a matching self-checking testbench in `sim/`.
"Self-checking" means the testbench itself computes the expected answer and
compares it to the DUT's output - `$display`-ing a `PASS`/`FAIL` line at the
end - rather than you eyeballing a waveform. All four are exhaustive (they
try every possible input combination), which is only feasible because these
input spaces are tiny (4, 64, 4, and 16 cases respectively); that stops
being realistic once a module has more than a handful of input bits, which
is a preview of why later modules will need smarter test strategies than
"try everything."

```sh
make sim                                  # runs the default testbench (tb_gates)
make SIM_TOP=tb_mux4to1 sim
make SIM_TOP=tb_decoder2to4 sim
make SIM_TOP=tb_priority_encoder4to2 sim
make sim-all                              # runs all four, stops at the first failure
```

This compiles `hdl/*.v` + `sim/*.v` with `xvlog`, elaborates just the
requested testbench with `xelab`, and runs it to completion with
`xsim -runall` - no Vivado project, no GUI, just compile → elaborate → run.
Output (and a saved log) lands in `_out/sim/`. `make sim` fails the build if
the testbench ever printed `FAIL`.

## Hardware demos

Four independent top-level wrappers, one per concept module, all sharing
the exact same `sw[3:0]`/`led[3:0]` interface `curriculum/00_first_bitstream`
established - which is why the constraints files in this module are
byte-for-byte copies of module 00's: as long as a top module's port names
and widths match, the same XDC works unchanged for a completely different
design.

```sh
make TOP=gates_top             BOARD=nexys4 bitstream   # (gates_top is the default TOP)
make TOP=mux_top               BOARD=nexys4 bitstream
make TOP=decoder_top           BOARD=nexys4 bitstream
make TOP=priority_encoder_top  BOARD=nexys4 bitstream
make program                                             # after picking a TOP above
```

What to try on hardware:

- **`gates_top`**: flip `sw[0]`/`sw[1]` through all four combinations and
  confirm all four LEDs match the AND/OR/XOR/NAND truth tables at once.
- **`decoder_top`**: flip `sw[1:0]` through 0-3 and confirm exactly one LED
  is lit each time, and that it's a *different* one each time.
- **`priority_encoder_top`**: set `sw = 4'b1010` (two switches on) and
  confirm the reported index is `3` (the higher one), not `1` - this is the
  one case that actually distinguishes a priority encoder from a plain one.
- **`mux_top`**: flip `sw[1:0]` and confirm `led[2]` follows
  `4'b1101[sw[1:0]]` (i.e. reads out `1,0,1,1` for `sel = 0,1,2,3`).

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| rfsoc4x2 | ready |
| blackboard | ready |
