# 11 - AXI4-Lite and custom IP

**Goal:** write an AXI4-Lite slave from scratch - every channel, every
handshake - then drop it into a block design behind a JTAG-driven AXI
master and poke its registers on live hardware from the Vivado Tcl
console. After this module, "it's AXI" stops being a black box.

## AXI4-Lite in one sitting (`hdl/axil_regs.v`)

Five channels, each an independent valid/ready handshake (transfer happens
on the clock edge where both are high; either side may stall freely):

| Channel | Direction | Carries |
|---|---|---|
| AW | master->slave | write address |
| W  | master->slave | write data + byte strobes |
| B  | slave->master | write response (OKAY/SLVERR) |
| AR | master->slave | read address |
| R  | slave->master | read data + response |

The register map: `0x00` SCRATCH (RW), `0x04` LED (RW, drives the board
LEDs), `0x08` STATUS (RO: switches + button), `0x0C` ID (constant
`0xF19A_1AB0`). Details the implementation gets right that toy examples
skip: AW and W accepted **in either order** (latched independently,
executed when both present), **byte strobes** honored per-lane,
out-of-range and read-only writes answered with **SLVERR** instead of
silently aliasing, one transaction outstanding at a time.

The `(* X_INTERFACE_INFO *)` attributes on the ports tell IP integrator
these 19 ports form one AXI4-Lite slave interface - which is what lets
the block design treat hand-written RTL as a first-class AXI block.

## The block design (`bd/jtag_axi_sys.tcl`)

Two ideas introduced:

- **RTL module reference**: `create_bd_cell -type module -reference
  axil_regs` places the plain Verilog module straight into the BD - no
  packaging step. (Full `ipx` packaging - a reusable catalog entry with
  its own versioning - is the heavier tool, deferred until a later module
  actually needs to *reuse* IP across projects.)
- **JTAG-to-AXI** (`jtag_axi`): an AXI master driven over the JTAG cable.
  It answers "who talks AXI before a processor exists?" - and it means
  Tier 5 can swap in the Zynq PS as the master *without touching
  axil_regs at all*. That substitutability is the entire point of bus
  standards, demonstrated rather than asserted.

Plus `proc_sys_reset` (the standard reset conditioner) and
`assign_bd_address` - the slave sits at `0x0000_0000`.

## Poking real registers over JTAG (do this)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
```

Then in Vivado: *Open Hardware Manager* -> connect -> the Tcl console:

```tcl
# read the ID register (expect f19a1ab0)
create_hw_axi_txn rd_id [get_hw_axis hw_axi_1] -type read -address 0000000C
run_hw_axi rd_id

# light LEDs 0 and 3 by writing 0b1001 to the LED register
create_hw_axi_txn wr_led [get_hw_axis hw_axi_1] -type write -address 00000004 -data 00000009
run_hw_axi wr_led

# read the switches/button
create_hw_axi_txn rd_st [get_hw_axis hw_axi_1] -type read -address 00000008
run_hw_axi rd_st
```

Registers you designed, on silicon, from a keyboard. Flip the board's
switches and re-run the STATUS read.

## Simulation

```sh
make sim-all    # tb_axil_regs
```

The bench implements a miniature AXI master as reusable tasks and covers
the full map, byte strobes, stalled channels, and both SLVERR cases. Two
handshake-bench lessons are preserved in its comments, both earned the
hard way during development: sample `ready` *before* the edge you're
judging (a slave may drop it the same edge it accepts), and give AW/W
**independent watcher threads** (`fork/join`) because one can be accepted
while the other is still deliberately stalled. Plus a watchdog - a
handshake bench must fail loudly, never hang.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
