# 00 - First bitstream

**Goal:** get a bitstream built and programmed by the scripted flow, on real
hardware, before worrying about any actual digital logic. Everything from
here on assumes this works.

## The design

`hdl/passthrough.v` wires 4 switches straight to 4 LEDs - `assign led = sw;`.
No clock, no registers, no state. That's deliberate: it isolates "does my
toolchain/constraints/build system work" from "did I write correct
sequential logic", which is a much easier thing to debug on its own.

## Why no clock yet

Nexys4 has a free-running 100 MHz oscillator wired straight into the fabric,
so a clocked design would be just as easy here. RFSoC4x2 and BlackBoard
don't: their PL fabric clock is normally sourced from the Zynq PS, which
isn't configured until `curriculum/13_zynq_ps_bringup`. Rather than special-
case the HDL per board this early, every board in this module uses the same
clockless design - a legitimate constraint-driven exercise in its own right
(it's still real synthesis, real place-and-route, real I/O standards).
Clocked designs (blinky counters, debouncers) start at
`curriculum/04_clock_dividers_and_debouncing`.

## Build & program

```sh
make BOARD=nexys4 bitstream      # or BOARD=rfsoc4x2
make BOARD=nexys4 program        # board must be connected over USB/JTAG
```

Flip switches 0-3 and confirm LEDs 0-3 follow them.

## What to look at afterwards

```sh
make BOARD=nexys4 gui
```

opens the generated project in the Vivado GUI. Worth looking at once:

- **Sources** pane - `passthrough.v` plus the constraints file that got
  added to the `constrs_1` fileset.
- **Reports > Implementation > Utilization** - four LUTs (or fewer -
  synthesis may optimize the passthrough into direct routes) for a "design"
  with no logic. This is a good moment to notice that even doing nothing
  still goes through real place-and-route.
- **I/O Planning** view - see the four switch and four LED pins actually
  placed on the die.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| rfsoc4x2 | ready |
| blackboard | ready |
