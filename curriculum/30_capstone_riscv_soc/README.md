# 30 - Capstone: a RISC-V SoC made entirely of fabric (Nexys4)

**Goal:** end where module 00 began - switches and LEDs on the Nexys4 -
but with a complete computer in between. MicroBlaze-V (AMD's RV32 soft
core) + 128KB BRAM main memory + AXI UART/GPIO/timer/interrupt
controller, all synthesized into the Artix-7. The board that spent the
whole curriculum as "the one without a processor" had one all along.

Of the three capstone candidates the syllabus floated, this is the
non-Linux one (the PYNQ-overlay candidate belongs after Tier 6; the SDR
application effectively happened in module 24). It also closes the one
conceptual gap left: on Zynq we always *borrowed* a hard CPU - here the
CPU is LUTs, and the same `make elf` flow from module 14 compiles for
it (Vitis ships a riscv toolchain; the BSP/XSA machinery doesn't care
that the target didn't exist before synthesis).

## What's in the block design (`bd/riscv_soc.tcl`)

- `microblaze_riscv` via its block automation: local BRAM as main
  memory, debug module (so `xsdb` can load ELFs over JTAG), AXI
  peripheral interconnect, AXI interrupt controller.
- `axi_uartlite` (115200) on the USB-UART pins, `axi_gpio` x2 (16 LEDs
  out, 16 switches in), `axi_timer` -> the intc through an xlconcat.
- Clock: the board's raw 100 MHz. Reset: the CPU_RESET button, active
  low, into proc_sys_reset - a real little computer with a real reset
  button.

## The software: a monitor shell (`src/main.c`)

```
riscv> h                 help
riscv> i                 identify (RV32, 100 MHz, made of LUTs)
riscv> l A5F             write led[14:0]
riscv> s                 read switches
riscv> u                 uptime - counted by the timer ISR
riscv> p 40600000        peek any address (try the peripherals)
riscv> w 40000000 FFFF   poke (that's the LED GPIO, by hand)
riscv> m                 mirror sw->led until a key: module 00 as an app
```

`led[15]` blinks at 1 Hz from the **timer interrupt** the entire time,
whatever the shell does - the visible difference between "a polling
loop" and "a computer". Peek/poke close the loop on modules 11/15:
the AXI map isn't an abstraction, it's addresses, and now you can
wander around it from a prompt.

## Build & run

```sh
make bitstream xsa elf
make program              # then load the ELF (xsdb: dow + con)
```

Terminal at 115200 on the same USB cable -> `riscv>`.

## Board status

| Board | Status |
|---|---|
| nexys4 | bitstream + xsa + elf build; bench run = the shell session above |
| blackboard / rfsoc4x2 | n/a here - they have hard CPUs; the soft-CPU lesson belongs on the board without one |
