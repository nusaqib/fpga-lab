# 10 - IP integrator intro

**Goal:** the two ways to consume Xilinx IP - inside a block design and as
standalone generated IP - both fully scripted, plus the two pieces of IP
that pay rent in every future module: the **Clocking Wizard** (real
derived clocks at last) and the **ILA** (eyes inside the live chip).

## What's here

| Piece | Role |
|---|---|
| `bd/clkwiz_sys.tcl` | creates a block design: clk_wiz (MMCM), 100MHz in -> 25MHz + locked out |
| `ip/debug_ila.tcl` | creates a standalone ILA IP (.xci): 26-bit + 1-bit probes, 1024 samples |
| `hdl/ipi_blinky_top.v` | instantiates the generated BD wrapper, counts in the 25MHz domain, hangs the ILA on the counter |
| `sim/sim_stubs.v` | behavioral stand-ins for both IPs so `make sim` needs no IP generation |

## Block designs as code

The `.bd` file is a **build artifact** here, never a committed source -
what's committed is the Tcl that creates it (`bd/clkwiz_sys.tcl`). The
build system hook (`BD_TCL` in the Makefile): on the first build,
`common/tcl/build_project.tcl` sources the script, generates output
products, and wraps the BD in an auto-generated HDL wrapper
(`clkwiz_sys_wrapper`) that plain RTL instantiates like any module.
Rebuilds reuse the existing BD untouched.

If you'd rather *draw* a design in the GUI (`make gui`, IP Integrator):
draw it, then export with `write_bd_tcl -force bd/mydesign.tcl` and commit
the export. Draw once, script forever - that's the discipline that keeps
block designs reviewable and reproducible.

Standalone IP works the same way with `IP_TCL`: `ip/debug_ila.tcl` runs
`create_ip` + `set_property` config, guarded so re-sourcing on every
build is a no-op.

## The Clocking Wizard - module 04's promise kept

Module 04 said: don't make clocks out of flip-flop toggles; when you need
a real different frequency, use the dedicated hardware. This is it. The
wizard wraps an **MMCM** (mixed-mode clock manager): the derived 25MHz
lands on the dedicated clock network, gets automatically generated timing
constraints (note the constraints file adds *nothing* for it), and comes
with a `locked` flag - which the top respects by holding its counter in
reset until the MMCM has actually locked. `led[3]` shows `locked`;
`led[2:0]` blink at three related rates from the 25MHz counter.

## The ILA - eyes inside the chip

The ILA is a logic analyzer built out of your own BRAM: it continuously
captures its probes into a ring buffer, stops on a trigger you set at
runtime, and uploads the waveform over JTAG. The flow, after
`make program`:

1. Open Vivado -> *Open Hardware Manager* -> connect. The device now shows
   `hw_ila_1` beside it (found via the `.ltx` probes file next to the
   bitstream in `_out/<board>/vivado/*.runs/impl_1/`).
2. In the ILA dashboard, add a trigger condition - e.g. `counter[22] == R`
   (rising) - and arm it.
3. It triggers, and you're looking at 1024 real cycles of the real
   counter inside the real chip. Change the trigger, re-arm, repeat -
   no rebuild.

From here on, any design that misbehaves on hardware gets an ILA before
it gets speculation. That habit is most of what this module is for.

## Simulation

```sh
make sim-all    # tb_ipi_blinky (against sim/sim_stubs.v)
```

Generated IP doesn't behaviorally simulate without its output products,
so `sim/sim_stubs.v` provides interface-exact stand-ins (a /4 divider
with a lock delay; an ILA that swallows its inputs). Stubs live in `sim/`
so hardware builds never see them. This is the standard technique for
simulating *your* logic around IP - with the honest caveat that the stub
is only as faithful as you wrote it.

## Hardware

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
