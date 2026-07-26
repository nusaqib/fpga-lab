# 09 - Timing closure basics

**Goal:** learn to read what the tools have been silently signing off on
since module 03. This module ships a design that *fails* timing on
purpose, its pipelined fix, and one honest multicycle path - because you
learn timing reports by having a real violation to stare at, not by
reading about one.

## The three designs (`hdl/`)

| Module | Role |
|---|---|
| `mult_chain_slow.v` | three chained 32x32 multiplies in ONE cycle - deliberately fails 100MHz |
| `mult_chain_pipelined.v` | same math, register after each multiply - passes with room to spare |
| `mcp_example.v` | the same slow cloud, but source and capture enabled every 4th cycle + `set_multicycle_path 4` - passes *honestly* |
| `slow_top.v` / `fast_top.v` | build wrappers keeping the logic alive on 4 LEDs |

## The exercise (do this, actually)

```sh
make TOP=slow_top BOARD=nexys4 bitstream    # completes, but FAILS timing
make TOP=fast_top BOARD=nexys4 bitstream    # passes
```

Then read the reports - both live under
`_out/nexys4/vivado/09_timing_closure_basics.runs/impl_1/`:

```sh
grep -A8 "Design Timing Summary" *_timing_summary_routed.rpt
```

For `slow_top` expect **negative WNS** (worst negative slack - the ns by
which the worst path misses the 10ns budget) and a violation count in
TNS/failing endpoints. For `fast_top`, positive WNS. To see the actual
worst path - the register-to-register route through all three DSP blocks -
open the `.xpr` in the GUI (`make gui`) and run *Reports -> Timing ->
Report Timing*: it shows every leg (clock->Q, DSP delays, net routing,
setup at the capture flop) summing to the total.

Vivado still writes a bitstream for `slow_top` (with a Critical Warning).
**Never program one**: a setup-violating path means the capture flop
samples mid-transition - wrong values, or worse, metastability (module
03's lesson, now self-inflicted). Timing closure = WNS >= 0, no waivers
you can't defend.

## What setup/hold actually are (one paragraph each)

**Setup**: data launched by one clock edge must arrive at the capture flop
*before* the next edge, minus the flop's setup window. The path budget is
one clock period minus clock skew/uncertainty; logic + routing must fit.
Fails when logic is too deep - the fix hierarchy: pipeline it (done here),
restructure it, floorplan it, or slow the clock.

**Hold**: data must *not* arrive so fast it corrupts the capture flop's
sampling of the *same* edge that launched it. Independent of clock period
- a hold violation at 100MHz is a hold violation at 1MHz. The router fixes
almost all of these by padding fast paths; a post-route hold violation is
rare and serious (usually bad clock skew or an unconstrained crossing).

## Multicycle vs false path - saying true things to the tools

`mcp_example` is the textbook honest MCP: both the source register and
capture register are enabled once every 4 cycles, so the cloud between
them genuinely has 4 periods to settle. The constraints say exactly that:

```tcl
set_multicycle_path -setup 4 -from .../x_r_reg/C -to .../result_reg/D
set_multicycle_path -hold  3 -from .../x_r_reg/C -to .../result_reg/D
```

(The `-hold N-1` companion moves the hold check back to the launch edge -
forgetting it is *the* classic MCP mistake; the tools would otherwise try
to meet hold at edge 3 and fail absurdly.)

`set_false_path` by contrast means "never check this, ever" - honest only
for genuinely asynchronous crossings (module 08's Gray pointers, the
button/switch pins since module 03) and static config. Using false_path
where multicycle is the truth silences the very check that would catch a
4-cycle budget that stopped sufficing.

## Simulation

```sh
make sim-all    # tb_mcp_example, tb_mult_chain
```

Behavioral sim is timing-blind - both chains simulate perfectly whatever
the clock. The benches prove the *functional* contracts (pipelined ==
slow with a 2-cycle offset; MCP result updates only on the 4-cycle grid),
and the timing story lives entirely in the implementation reports. Both
things are needed; neither substitutes for the other.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready (slow_top intentionally fails timing - that's the exercise) |
| blackboard | ready (same) |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
