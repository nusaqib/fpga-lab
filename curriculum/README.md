# The journey: syllabus

Every module is a self-contained, buildable directory (`README.md` + `hdl/` +
`constraints/` + `Makefile`, see `docs/build_system.md` at the repo root).
Modules are numbered in the order they should be done - later modules assume
everything before them. Boards used per module are noted; "all" means the
exercise is worth repeating on every board you have, since the interesting
part is seeing the *same* HDL retargeted through different constraints/parts.

Status legend: `[ ]` not started, `[x]` done, `[~]` in progress.

## Tier 0 - Toolchain & first bitstream

- [x] `00_first_bitstream` - scripted Vivado flow end to end: switches wired
  straight to LEDs, no clock. Proves the Makefile/Tcl build system,
  constraints, and JTAG programming all work before any real design content.
  Boards: all three.

## Tier 1 - Combinational logic

- [x] `01_combinational_logic` - gates, muxes, decoders, priority encoders in
  Verilog; `assign` vs always-block combinational style; simulation basics
  (a testbench for the first time - `make sim`/`sim-all` now exist, xvlog/
  xelab/xsim, no project needed). Boards: all three, verified building.
- [x] `02_arithmetic_circuits` - adders (ripple-carry, then a concrete
  carry-lookahead adder cross-checked against it), comparators, ALU.
  Introduces `generate`. All sims pass; all six demos built on Nexys4,
  spot-checked on RFSoC4x2 + BlackBoard.

## Tier 2 - Sequential logic & clocking

- [x] `03_flip_flops_and_registers` - D flip-flops (async/sync reset,
  enable), registers, why non-blocking (`<=`) matters, metastability intro
  (sync2 + ASYNC_REG). First clocked module; nexys4 + blackboard built,
  rfsoc4x2 deferred to Tier 5 (no PL clock).
- [x] `04_clock_dividers_and_debouncing` - tick_gen enable idiom (and the
  derived-clock trap), counter-based debouncer, edge detect; classic 1Hz
  blinky + press counter. The naive-vs-debounced bench counts 35 vs 5 for
  5 bouncy presses. nexys4 + blackboard built.
- [x] `05_counters_and_shift_registers` - up/down counter, SIPO shift
  register, self-correcting ring counter, maximal-length LFSR (period-15
  proof); power-up initializer idiom. Built on nexys4 + blackboard.
- [x] `06_finite_state_machines` - Moore vs Mealy twin "1011" detectors
  (one-cycle difference asserted in the bench), FSM style rules, and a
  pedestrian-crossing traffic light with min-green + latched request.
  Built on nexys4 + blackboard.

## Tier 3 - Memory & timing

- [x] `07_block_ram_and_fifos` - inferring BRAM (registered read,
  collision semantics, ram_style), synchronous FIFO with the
  extra-pointer-bit trick, verified against an SV queue model; async FIFO
  deferred to 08 as the CDC capstone. Built on nexys4 + blackboard.
- [x] `08_clock_domain_crossing` - pulse_sync (toggle method),
  handshake_sync (4-phase), and the Gray-pointer async FIFO capstone, all
  proven under unrelated sim clocks both directions; thumb-as-write-clock
  hardware demo. Built on nexys4 + blackboard.
- [x] `09_timing_closure_basics` - a deliberately-failing triple-multiply
  (WNS -8.679ns, 80 failing endpoints, confirmed on a real build - go read
  the report), its pipelined fix (passes), and an honest multicycle path
  with the -hold N-1 companion. Built on nexys4 + blackboard.

## Tier 4 - IP integrator, AXI, and going bigger

- [x] `10_ip_integrator_intro` - block designs as code (BD_TCL/IP_TCL build
  hooks; .bd is an artifact, the creating Tcl is the source), Clocking
  Wizard/MMCM (module 04's promise kept), and an ILA on the live counter
  with the trigger walkthrough. Sims pass (IP stubbed); hardware builds
  queued.
- [x] `11_axi_and_custom_ip` - a hand-written AXI4-Lite slave (all five
  channels, byte strobes, SLVERR), dropped into a BD as an RTL module
  reference behind a JTAG-to-AXI master - registers pokeable from the
  Vivado Tcl console with no CPU. Built on nexys4 + blackboard.
- [x] `12_axi_stream` - AXI-Stream fundamentals: an honest AXIS master,
  the skid buffer (registered-ready with a one-beat catch register - THE
  stream structure), and an AXIS sink with a JTAG-readable AXI4-Lite
  window. Real AXI DMA deferred to Tier 5 where actual DDR exists (noted
  in the module README). Sims pass under hostile random backpressure;
  built on nexys4 + blackboard.

## Tier 5 - Zynq processing system bring-up

- [x] `13_zynq_ps_bringup` - PS+PL block designs for both Zynq boards
  (PS7 + PSU side by side), presets applied from the vendored board files
  via the new board.repoPaths hook; pl_clk0 finally alive - the RFSoC4x2's
  first clocked PL design built and verified, plus both boards' first
  `.xsa` exports (make xsa). Vitis "hello world" moves to module 14.
- [x] `14_bare_metal_gpio_and_interrupts` - first software module: C on
  the A9/A53 drives AXI GPIO over M_AXI_GP0, and a real fabric interrupt
  (AXI GPIO -> IRQ_F2P/pl_ps_irq0 -> GIC -> ISR) replaces polling; main()
  sleeps in wfi. Toolchain note: XSCT is disabled in Vitis 2026.1 - the
  build system's software path (vitis.mk + common/tcl/build_app.py) uses
  the Vitis Python interface. bitstream+xsa+elf build on both Zynq boards.
- [x] `15_custom_ip_from_ps` - the processor drives OUR peripheral:
  module 11's axil_regs behind M_AXI_GP0/HPM0_FPD, its "driver" two
  one-line Xil_In32/Out32 wrappers, self-checking PASS/FAIL over UART.
  Base address pinned deterministically (range-then-offset - a
  full-aperture segment can't be moved). RFSoC lesson: pl_clk0 is really
  99999985 Hz, so no hardcoded FREQ_HZ on module-reference interfaces;
  PSU-side AXI wired by hand after automation dangled a clk_wiz. Full
  flow (bitstream+xsa+elf) green on both Zynq boards.

## Tier 6 - Embedded Linux

*(Toolchain note: this tier was originally scoped for PetaLinux, which AMD
has since superseded with the Embedded Development Framework - EDF, plain
upstream Yocto + AMD layers, first shipped with 2025.1; PetaLinux is
EOL-bound. Tier 6 uses EDF: it's what the industry migrates to, it teaches
real Yocto instead of a retiring wrapper, and it needs no installer,
license, or AMD account - see `docs/tool_setup.md`.)*

- [~] `16_edf_linux_bringup` - a minimal Linux for BlackBoard and RFSoC4x2
  with EDF/Yocto, boot over SD. The custom-hardware chain, all from tools
  we already have: `make xsa` -> `sdtgen` (XSA -> System Device Tree) ->
  `gen-machineconf parse-sdt` (SDT -> Yocto MACHINE, including FSBL/PMU
  multiconfigs) -> `bitbake`. Chain proven end to end for rfsoc4x2; first
  image build in progress.
- [x] `17_device_trees_and_drivers` - module 15's `axil_regs`, unchanged,
  meets the kernel: sdtgen turns the BD address map into a `pl.dtsi` node
  (`compatible = "xlnx,axil-regs-1.0"`, verified on both boards), and
  `uio_pdrv_genirq of_id=` binds it WITHOUT falsifying the compatible to
  `generic-uio`. New repo-side Yocto layer `linux/meta-fpgalab` (opt-in
  bootargs dtsi via the device-tree recipe's `EXTRA_DT_INCLUDE_FILES`
  hook). Userspace UIO driver in C, address discovered through sysfs, no
  hardcoded base anywhere. Cross-compiled with the Linux toolchains that
  ship inside Vitis. (On-target run pending module 16's image - bench.)
- [x] `18_linux_userspace_apps` - hardware as an ordinary programming
  target: `Uio`/`DevMem`/`dt_find` in pure-stdlib Python (reg base decoded
  from `/proc/device-tree` with the parent's cell sizes - <1,1> zynq vs
  <2,2> zynqmp, host-verified on both geometries), module 15's demo from
  Python, `/dev/mem` C twin as the cautionary tale, and the payoff:
  module 24's SDR from a shell prompt (`sdr_capture.py 240 -240 480`) -
  DDS tone, snap capture, pure-Python FFT host-verified on module 24's
  exact tone set. `meta-fpgalab` grows app recipes + `fpgalab-image`
  (minimal + python3 + our tools). (Recipes' first bitbake queued behind
  module 16's build; on-target runs are bench items.)

## Tier 7 - High-level synthesis & DSP

- [x] `19_hls_intro` - module 12's stream scaler as ~15 lines of HLS C++:
  csim -> csynth (II=1, ~74 LUT, est. 220MHz) -> cosim against the
  generated Verilog. Honest comparison table vs the hand-written skid
  buffer. Toolchain: no vitis_hls binary in 2026.1 - common/mk/hls.mk
  wraps `v++ --mode hls` + `vitis-run` with a generated per-board config.
- [x] `20_dsp_fundamentals` - Q1.15 end to end (growth, round-to-nearest,
  saturation planted via coefficients summing to exactly 1.0), a 4-tap FIR
  twice: hand transposed-form Verilog (4 DSP48s via `make ooc`, the new
  out-of-context synth target) vs HLS (2 DSPs - it found the symmetric-FIR
  pre-adder trick unasked). Bit-exact against one shared model; sims,
  cosim, and OOC synth all green. Bonus lesson: 0.25 coefficients cost
  zero multipliers (2^13 is a shift) - constant choice changes hardware.
- [x] `21_hls_streaming_and_dataflow` - FIR + decimate-by-2 as one
  DATAFLOW kernel (task-level vs instruction-level parallelism, internal
  hls::stream with a plain struct - ap_axiu is ports-only, HLS 214-208),
  packaged as Vivado IP (`make hls-package`, new) and dropped into module
  12's src->capture pipeline: bitstreams on nexys4 + blackboard, LEDs
  jump by 8 per press (decimation visible), JTAG-readable capture.

## Tier 8 - RF data converters (RFSoC4x2)

- [x] `22_rf_dc_intro` - the RFDC IP bare-metal: the LMK04828/LMX2594
  clock chain programmed over PS SPI0 (register dumps vendored from the
  official RFSoC-PYNQ repo - without this the tiles never leave reset),
  tile-2 pair (DAC_A/ADC_A SMAs) at 4.9152 GSPS with on-tile PLLs, DC +
  fine-mixer NCO = 1 GHz carrier with zero fabric DSP, ADC NCO brings it
  back to 100 MHz, new axis_snap BRAM recorder + zero-crossing frequency
  measurement in C. bitstream+xsa+elf green; bench run needs an SMA cable
  (DAC_A -> ADC_A).
- [x] `23_digital_up_down_conversion` - same bitstream as 22, radio
  reconfigured at runtime (the lesson itself): fine-NCO sweep tracks
  |f_carrier - f_nco| row by row (with the negative-frequency fold a
  single component can't resolve), coarse fs/4 mixer (multiply-free:
  1,-j,-1,j), runtime decimation 2x->4x showing "wrong math reads 200MHz,
  rate-aware math reads 100MHz again". bitstream+xsa+elf green; bench
  run pending SMA loopback.
- [x] `24_sdr_mini_project` - Tiers 7+8 combined into a working SDR:
  HLS DDS transmitter (phase accumulator + ROMs, s_axilite phase_inc
  register alongside ap_ctrl_none streaming), axis_combiner packs I+Q
  into one 256-bit beat (simultaneous samples - two recorders could
  never), 1024-pt libm-free FFT on the A53 (11 twiddle literals + the
  rotation recurrence, host-verified), ASCII spectrum, and a tone sweep
  whose verdict requires the peak on the correct SIDE of DC - the thing
  module 23's single-component capture fundamentally couldn't see.
  csim/cosim/sim + bitstream+xsa+elf green; bench run pending SMA.

## Tier 9 - High-speed I/O & networking

- [x] `25_gigabit_ethernet` - GEM1 + DP83867 over MIO on RFSoC4x2 (the
  one board here with Ethernet), bare-metal lwIP RAW-mode TCP echo
  server: the stack as a library - main loop pumps xemacif_input(),
  a 50ms xiltimer tick drives tcp_fasttmr/slowtmr (skip that and TCP
  dies on the first lost packet), connections are callbacks. New
  BSP_LIBS knob in vitis.mk/build_app.py (domain.set_lib). Static
  192.168.1.10, ping + nc port 7. bitstream+xsa+elf green; bench run
  pending an Ethernet cable.
- [x] `26_high_speed_serial_intro` - the GTY quad behind the QSFP28
  cage (quad 128, refclk AA33/AA34 @ 156.25MHz - RealDigital reference
  manual Appendix A, cross-checked against Vivado's MGTREFCLK0_128 pin
  mapping) running IBERT at 10.3125 Gb/s: PRBS patterns, BER, internal
  PMA loopback (no QSFP module needed), silicon-measured eye scans.
  README carries the concepts: CDR, why encoding exists, quads/QPLLs,
  refclk purity. Bitstream builds; bench run = Hardware Manager session.
- [x] `27_pmod_and_onboard_peripherals` - a real external peripheral,
  full stack from constraints to driver, no CPU: the Nexys4's ADT7420
  over I2C (same electrical/protocol reality as any Pmod). Hand-written
  byte-level I2C master, datasheet transactions as an FSM (ID check +
  temperature, the load-bearing repeated START), from-scratch UART TX,
  "T=+025.5C" lines at 115200. The bench contains a behavioral ADT7420
  slave - being both ends of the protocol is half the module. Caught
  before hardware: inverted read-ACK, x-prop from missing initializers,
  and a from-memory pinout that was the Nexys4-DDR's (vendored XDC won).

## Tier 10 - Mastery / capstone

- [x] `28_verification_basics` - directed vs constrained-random, proven
  on a planted bug (registered full flag, one cycle late): the careful
  directed bench passes on the BROKEN FIFO (its pass criterion encodes
  that), bursty random + SV-queue scoreboard catches the corruption at
  cycle 43. SVA invariants + functional coverage as hand-rolled counters
  (with its own meta-lesson: an uninitialized histogram counts x+1=x and
  defeats the hole check). Simulation-only by design. cocotb: blocked on
  tooling (no pip/sudo); concepts transfer verbatim when installed.
- [x] `29_multiboard_project` - Nexys4 and BlackBoard talking over a
  crossed Pmod cable: identical link_node RTL both ends (ID parameter +
  pins differ), 4-byte checksummed heartbeat at 115200, each board's
  LEDs showing the OTHER board's counter, link_up from a 3-beat timeout
  (cut the cable -> drops; replug -> self-heals, no stored state). New
  uart_rx with mid-bit sampling - the bench runs both nodes at 100.00
  vs 100.30 MHz on purpose, plus corruption/cut/heal phases. RFSoC4x2
  deliberately omitted: Pmod signal voltage unverified (LVCMOS18 bank,
  3.3V connector Vdd, manual silent on shifting) - volts obey the same
  truthfulness rule as pins. Sims green; both bitstreams build.
- [x] `30_capstone_riscv_soc` - of the three floated candidates, the
  non-Linux one (PYNQ overlays belong after Tier 6; the SDR app
  effectively happened in module 24): a complete RISC-V SoC in the
  Nexys4's fabric. MicroBlaze-V + 128KB BRAM + UART/GPIO/timer/intc,
  the same `make elf` flow as module 14 now emitting a UCB RISC-V
  executable for a CPU that didn't exist before synthesis. The software
  is a monitor shell (peek/poke the AXI map by hand, mirror sw->led "as
  an app" - module 00 with a computer in between) with a timer-ISR
  heartbeat on led[15]. bitstream+xsa+elf green; bench run = the shell.

---

## Board applicability at a glance

| Tier | Nexys4 | BlackBoard | RFSoC4x2 |
|---|---|---|---|
| 0-3 (logic, sequential, memory, timing) | yes | yes* | yes* |
| 4 (IPI/AXI/DMA) | yes | yes | yes |
| 5-6 (Zynq PS, Linux) | no PS - skip | yes | yes |
| 7 (HLS/DSP) | yes (no PS needed for HLS IP in PL-only designs) | yes | yes |
| 8 (RF data converters) | n/a | n/a | yes only |
| 9 (high-speed I/O) | partial (no GTY) | partial | yes |

`*` BlackBoard and RFSoC4x2 need the pushbutton-as-clock workaround until
Tier 5, since neither has a free-running clock wired straight into the PL
fabric the way Nexys4 does (see `boards/rfsoc4x2/docs/README.md` and
`boards/blackboard/docs/README.md` - BlackBoard actually does have a 100MHz
PL oscillator on pin H16, so it can join Nexys4 a little earlier if you want
to jump ahead).

## Suggested pace

This is a marathon, not a sprint - there's no deadline here. A reasonable
cadence is one module every session or two, actually building and
programming real hardware each time rather than just reading. Skipping ahead
when a tier feels too easy is fine; skipping *back* to fill a gap you notice
later is encouraged, not a failure.
