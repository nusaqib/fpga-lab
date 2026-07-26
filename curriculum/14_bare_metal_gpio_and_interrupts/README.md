# 14 - Bare-metal GPIO and interrupts

**Goal:** the first software module. C code running on the Zynq's ARM
cores (Cortex-A9 on BlackBoard, Cortex-A53 on RFSoC4x2) drives the same
LEDs and reads the same buttons module 00 wired straight through -
except now they're registers behind an AXI address, and "the design"
is a program. Both ways of noticing a button are demonstrated: polling
and a real fabric interrupt through the GIC.

## The hardware side (`bd/`)

Module 13's PS bring-up, extended with exactly the pieces this module is
about:

- **M_AXI_GP0** switched on - the PS's master port into PL address
  space (on the UltraScale+ it's called `M_AXI_HPM0_FPD`; same role).
- A dual-channel **AXI GPIO**: channel 1 drives 4 LEDs, channel 2 reads
  4 buttons, placed at an AXI address by `assign_bd_address`.
- The GPIO's **`ip2intc_irpt` interrupt** wired into the PS fabric
  interrupt input (`IRQ_F2P` / `pl_ps_irq0`) - the PL can now wake the
  processor instead of being polled.

Connection automation builds the interconnect and clocks it all from the
PS fabric clock. Note the constraints still contain no clock pin.

## The software side (`src/main.c`, built by the Vitis Python flow)

**Toolchain note (2026.1):** XSCT - the classic scripted Vitis interface -
is disabled in this release. The build system's software path
(`common/mk/vitis.mk` -> `common/tcl/build_app.py`) uses the Vitis
**Python** interface (UG1400): create a platform component from this
module's exported `.xsa`, build the BSP, create the app component, swap
in `src/`, build. All of it lands in the gitignored `_out/<board>/vitis_ws/`.

The program itself:

1. **GPIO by register**: initialize the `XGpio` driver at the base
   address the BSP extracted from the hardware (`XPAR_XGPIO_0_BASEADDR` -
   the SDT-flow BSPs address drivers by base address, not the old device
   IDs), set channel directions, walk the LEDs.
2. **Interrupts**: `XSetupInterruptSystem` (the SDT `xinterrupt_wrap`
   helper) routes the GPIO's interrupt through the GIC to `btn_isr`;
   channel-2 interrupts are enabled in the GPIO. The ISR acks, counts
   presses, and shows the count on the LEDs. `main()` then mostly sleeps
   in `wfi` - the idle loop does nothing until hardware says otherwise.
   (No debouncer in the PL this time: bounce shows up as extra interrupt
   events, which is worth *seeing* - compare the press counter's jumps
   with module 04's clean single-step.)

## Build everything

```sh
make BOARD=blackboard bitstream xsa elf     # or BOARD=rfsoc4x2
```

Products: bitstream, `.xsa` platform, and
`_out/<board>/vitis_ws/<app>/build/*.elf`.

## Run on the board (JTAG, no SD card needed)

In the Vitis Unified IDE (or `xsdb`, which still exists in 2026.1 for
debugging): program the bitstream, then download and run the ELF on the
first ARM core. Watch the UART at 115200 (the FT2232's second channel on
both boards):

```
== fpga-lab module 14: bare-metal GPIO + interrupts ==
LED walk done - GPIO writes reach the pins.
Interrupts armed - press buttons; LEDs count presses.
press event #1 (btn=0x1)
```

On BlackBoard, boot-mode jumper to JTAG for a clean start. On RFSoC4x2
the stock SD firmware will have booted first; JTAG-loading the ELF onto
core 0 replaces whatever it was doing.

## Board status

| Board | Status |
|---|---|
| blackboard | ready (bitstream + xsa + elf all build) |
| rfsoc4x2 | ready (bitstream + xsa + elf all build) |
| nexys4 | n/a - no processor |
