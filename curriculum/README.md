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
  proof); power-up initializer idiom. Sims pass; hardware builds queued.
- [x] `06_finite_state_machines` - Moore vs Mealy twin "1011" detectors
  (one-cycle difference asserted in the bench), FSM style rules, and a
  pedestrian-crossing traffic light with min-green + latched request.
  Sims pass; hardware builds queued.

## Tier 3 - Memory & timing

- [~] `07_block_ram_and_fifos` - inferring BRAM (registered read,
  collision semantics, ram_style), synchronous FIFO with the
  extra-pointer-bit trick, verified against an SV queue model; async FIFO
  deferred to 08 as the CDC capstone. Sims pass; hardware builds queued.
- [ ] `08_clock_domain_crossing` - two-flop synchronizers, handshake CDC,
  Vivado CDC reports.
- [ ] `09_timing_closure_basics` - reading a timing report, setup/hold,
  false paths, multicycle paths - using whatever module up to now is tightest.

## Tier 4 - IP integrator, AXI, and going bigger

- [ ] `10_ip_integrator_intro` - block design basics, Clocking Wizard, VIO/ILA
  for on-chip debug (a genuinely useful skill introduced here and reused
  everywhere after).
- [ ] `11_axi_and_custom_ip` - AXI4-Lite from scratch, packaging your own IP,
  wiring it into a block design.
- [ ] `12_dma_and_streaming` - AXI-Stream, AXI DMA, moving real data between
  PL and a memory-mapped source/sink.

## Tier 5 - Zynq processing system bring-up

- [ ] `13_zynq_ps_bringup` - first PS+PL block design; Blackboard (Zynq-7000,
  `processing_system7`) and RFSoC4x2 (Zynq UltraScale+, `zynq_ultra_ps_e`)
  side by side; this is where `pl_clk0` first becomes available on those two
  boards. First `.xsa` export, first Vitis bare-metal "hello world".
- [ ] `14_bare_metal_gpio_and_interrupts` - PS-side GPIO, interrupts, timers
  in Vitis, driving the same LEDs/buttons `00_first_bitstream` used, now from
  software.
- [ ] `15_custom_ip_from_ps` - PS talking to your own AXI IP from Tier 4.

## Tier 6 - Embedded Linux

- [ ] `16_petalinux_bringup` - build a minimal Linux for Blackboard and
  RFSoC4x2 with PetaLinux, boot over SD.
- [ ] `17_device_trees_and_drivers` - wiring a custom PL peripheral into the
  device tree; a minimal kernel module or UIO-based userspace driver.
- [ ] `18_linux_userspace_apps` - talking to hardware from Python/C on Linux
  (mmap'd registers, `/dev/uio*`).

## Tier 7 - High-level synthesis & DSP

- [ ] `19_hls_intro` - Vitis HLS: C/C++ to RTL for a simple filter, comparing
  hand-written HDL vs HLS output.
- [ ] `20_dsp_fundamentals` - fixed-point arithmetic, DSP48 slices, a FIR
  filter (HDL and HLS versions).
- [ ] `21_hls_streaming_and_dataflow` - `hls::stream`, dataflow pipelining,
  integrating an HLS IP into the Tier 4/5 AXI-Stream infrastructure.

## Tier 8 - RF data converters (RFSoC4x2)

- [ ] `22_rf_dc_intro` - the RFDC IP, configuring ADC/DAC tiles, loopback
  test between a DAC and ADC channel over SMA.
- [ ] `23_digital_up_down_conversion` - NCOs, mixers, decimation/interpolation
  on the RFDC tiles.
- [ ] `24_software_defined_radio_mini_project` - a small end-to-end SDR
  exercise combining Tiers 7-8 (e.g. a tone generator + spectrum viewer, or a
  simple AM/FM demod).

## Tier 9 - High-speed I/O & networking

- [ ] `25_gigabit_ethernet` - GEM/RGMII on the Zynq PS, a simple Linux or
  bare-metal networked app.
- [ ] `26_high_speed_serial_intro` - GTY transceivers on RFSoC4x2 conceptually
  (QSFP28), what a serial link bring-up actually involves.
- [ ] `27_pmod_and_syzygy_peripherals` - a real off-board peripheral over
  Pmod/SYZYGY, full stack from constraints to driver.

## Tier 10 - Mastery / capstone

- [ ] `28_verification_basics` - a step up from ad hoc testbenches:
  self-checking testbenches, functional coverage concepts, maybe a first
  look at cocotb.
- [ ] `29_multiboard_project` - a project spanning two boards talking to each
  other (e.g. UART/Ethernet link between Nexys4 and RFSoC4x2).
- [ ] `30_capstone` - open-ended, defined once we get here based on what's
  most interesting by then (candidates: a PYNQ-style overlay workflow on
  RFSoC4x2, a soft-core RISC-V on Nexys4, a real SDR application).

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
