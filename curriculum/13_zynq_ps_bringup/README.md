# 13 - Zynq PS bring-up

**Goal:** Tier 5 opens. The processing systems on both Zynq boards come
alive - BlackBoard's Zynq-7000 (`processing_system7`) and RFSoC4x2's
UltraScale+ (`zynq_ultra_ps_e`) side by side - each handing the PL its
first PS-generated fabric clock. For the RFSoC4x2, that is *the* unlock:
its first clocked PL design in this curriculum, after thirteen modules of
"deferred until Tier 5". Plus the first `.xsa` export - the handoff
artifact Vitis software work (module 14) builds on.

## The two block designs (`bd/`)

Same shape, different silicon:

| | BlackBoard | RFSoC4x2 |
|---|---|---|
| PS IP | `processing_system7` (2x Cortex-A9) | `zynq_ultra_ps_e` (4x A53 + 2x R5) |
| Fabric clock | `FCLK_CLK0`, set to 100MHz | `pl_clk0`, set to 100MHz |
| DDR | DDR3, timings from vendored board files | DDR4, config from vendored board files |
| PS pins in wrapper | DDR/FIXED_IO inouts passed through the top | none (fully dedicated) |

The load-bearing line in both scripts is block automation with
`apply_board_preset "1"`: the DDR timings, MIO assignments, and clock
tree come from the **vendored board files** (`boards/*/board_files`, made
visible to Vivado via `board.repoPaths` - see the build-system note
below), not from hand-typed configuration. Hundreds of `PCW_*`/`PSU__*`
values, sourced from the same hardware truth RealDigital's own reference
designs use. After the preset, each script trims to bring-up essentials:
one 100MHz PL clock, AXI masters off (module 14 turns them on), and a
`proc_sys_reset`-conditioned `pl_resetn`.

**Build-system addition:** `common.mk` now exports every
`boards/*/board_files` dir as `FPGA_LAB_BOARD_REPOS`, and
`build_project.tcl` feeds that to `set_param board.repoPaths` - so
`BOARD_PART` resolution and preset application work in every build
without touching `~/.Xilinx` config. Also new: `make xsa`.

## What "the PS releases the PL" means

The PL payload (`ps_blinky_core`) holds its counter in reset until
`pl_resetn` asserts. On a Zynq, the PL clock literally does not tick
until the PS (or on a bare board, the boot ROM + FSBL configuring PS
clocking) brings it up - the dependency every earlier module documented
as "no free-running PL clock" is now visible as a *reset sequence you
participate in* rather than an obstacle.

Note the constraints files: **no clock pin**. `pl_clk` is internal,
constrained automatically by the PS configuration. The RFSoC4x2 file is
the first constraints file for that board with a clocked design behind
it, and it's four LED pins.

## Build, program, export

```sh
make BOARD=blackboard bitstream    # default board for this module
make BOARD=rfsoc4x2  bitstream
make BOARD=<b> program
make BOARD=<b> xsa                 # -> _out/<b>/vivado/13_zynq_ps_bringup_<b>.xsa
```

On hardware: LEDs blink at four related rates once the PS is up. On
RFSoC4x2 the board boots its stock firmware from SD/QSPI, which
configures the PS - programming the PL bitstream over JTAG then rides on
that. (Full control of the boot flow - FSBL, our own PS init - is exactly
what the Vitis flow in module 14 and the PetaLinux flow in Tier 6 add.)

The `.xsa` contains the PS configuration + bitstream and is what Vitis
consumes to build bare-metal software with the right initialization -
module 14's "hello world over UART" starts from it.

## Simulation

```sh
make sim-all    # tb_ps_blinky_core
```

The PS has no useful behavioral model at this level; what's verified is
the PL payload's contract with it (hold in reset until released, then
count). PS-side verification happens on silicon, with software - that's
Tier 5's nature.

## Board status

| Board | Status |
|---|---|
| blackboard | ready |
| rfsoc4x2 | ready - first clocked PL design for this board |
| nexys4 | n/a - no PS on an Artix-7 (this module is the one place nexys4 sits out) |
