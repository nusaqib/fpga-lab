# 15 - Custom IP from the PS

**Goal:** close the loop that Tier 4 opened. Module 11 built `axil_regs`,
our own AXI4-Lite peripheral, and poked it from the JTAG Tcl console.
Module 14 had the processor drive Xilinx's AXI GPIO through a Xilinx
driver. This module puts the two together: the processor drives *our*
peripheral - for which no driver exists, because we invented it.

That's the lesson: **a driver for a memory-mapped peripheral is nothing
but reads and writes at base + offset.** `src/main.c`'s entire "driver"
is two one-line functions wrapping `Xil_In32`/`Xil_Out32`. Everything
else is knowing the register map - which lives in one place,
`hdl/axil_regs.v` (copied verbatim from module 11, same map, same ID
`0xF19A1AB0`).

## Structure

- `bd/ps_regs_sys_<board>.tcl` - PS (presets from vendored board files,
  as in modules 13/14) + `axil_regs` as a module reference on
  `M_AXI_GP0`/`M_AXI_HPM0_FPD`. The base address is **pinned
  deliberately** (`0x43C0_0000` PS7 / `0xA000_0000` PSU) rather than left
  to auto-assignment - module-reference RTL blocks don't always get an
  `XPAR_` macro in the BSP (no driver to attach it to), and the C code
  carries a matching guarded fallback. Deterministic beats discovered,
  when discovery isn't guaranteed.
- `src/main.c` - self-checking, PASS/FAIL over UART: reads the ID
  register (discovery), walks patterns through SCRATCH (write/readback),
  walks the LEDs through our LED register, then mirrors switches to LEDs
  through the CPU forever - the same physical pins module 00 wired
  together with zero logic, now routed through a fetch-decode-execute
  loop and an AXI interconnect. Same observable behavior, wildly
  different plumbing; worth a moment's appreciation.
- `sim/tb_axil_regs.v` - module 11's protocol bench, re-run here
  unchanged against the copied RTL (`make sim-all`).

## Build & run

```sh
make BOARD=blackboard bitstream xsa elf     # or BOARD=rfsoc4x2
```

Run over JTAG exactly as module 14's README describes. Expected UART:

```
== fpga-lab module 15: custom IP from the PS ==
ID register: 0xf19a1ab0 (ours!)
scratch write/readback done
LED walk done (via axil_regs, not axi_gpio)
RESULT: PASS
now mirroring switches to LEDs via software...
```

## Board status

| Board | Status |
|---|---|
| blackboard | ready (bitstream + xsa + elf all build) |
| rfsoc4x2 | ready (bitstream + xsa + elf all build) |
| nexys4 | n/a - no processor |
