# 18 - Linux userspace apps: hardware from Python and C

**Goal:** close Tier 6 by making PL hardware feel like an ordinary
programming target: open a device, mmap it, poke registers from a REPL.
The payoff is module 24's SDR driven from a Python prompt - what took a
recompile-and-JTAG cycle per experiment on bare metal becomes
`sdr_capture.py 240 -240 480` at a shell.

No hardware of its own: the register demos run on module 17's design
(module 15's `axil_regs`), the SDR capture on module 24's `sdr_sys`.

## What's here

- `py/uio.py` - the module's core. Three small tools:
  - `Uio` - find a UIO device by sysfs name, mmap map0, read32/write32.
  - `DevMem` - the same window through raw `/dev/mem` (root, no driver).
  - `dt_find` - walk `/proc/device-tree` and decode a node's `reg` with
    the parent's `#address-cells`/`#size-cells`, so even the /dev/mem
    path gets its address from the kernel's own hardware description
    instead of a constant. (Cells differ per family - <1,1> on Zynq-7000,
    <2,2> on ZynqMP - which is exactly why you decode instead of assume;
    verified against synthetic trees of both geometries.)
- `py/blink.py` - module 15's demo, third language: ID check, scratch,
  live STATUS, LED walk, via `Uio`.
- `py/sdr_capture.py` - set the DDS tone, arm `axis_snap_iq`, read 8192
  IQ samples, 1024-point FFT (pure Python - instant at this size, no
  numpy on the minimal image), report the spectrum peak. Register
  offsets from the RTL; base addresses from `dt_find` at runtime. The
  FFT/peak path is host-verified against module 24's exact tone set
  (+240/-240/+480/-720/+96 MHz, all peak in the right 2.4 MHz bin).
- `src/devmem_regs.c` - the C twin of `DevMem`, and the cautionary half
  of the lesson: root-only, no interrupts, no isolation,
  CONFIG_STRICT_DEVMEM caveats - the reasons module 17 bothered with a
  driver at all.
- `linux/meta-fpgalab` grows the packaging (this module's other half -
  getting your code ONTO the image the Yocto way):
  - `uio-regs` recipe - cross-compiles module 17's app with the image's
    own toolchain, sources pulled straight from the curriculum tree.
  - `fpgalab-py` recipe - installs the Python tools.
  - `fpgalab-image` - core-image-minimal + python3 + kernel-modules
    (uio_pdrv_genirq lives there) + both recipes. Build:
    `MACHINE=<board> bitbake fpgalab-image xilinx-bootbin`.

## Build & verify (host side)

```sh
make BOARD=blackboard all      # cross-compile C app + byte-compile Python
make BOARD=rfsoc4x2 app
```

## On the target

```sh
modprobe uio_pdrv_genirq of_id=xlnx,axil-regs-1.0    # module 17's binding
blink.py                                             # LEDs from Python
devmem_regs 0x43c00000                               # the raw-memory way
sdr_capture.py 240 -240 480                          # module 24's design, SMA loop
```

## Honest scoping

`sdr_capture.py` drives the DDS and capture blocks; it does NOT (yet)
program the LMK/LMX clock chain or the RFDC tiles - module 24's
bare-metal `main.c` does that, and porting it to Linux means the rfdc
userspace stack (the PYNQ route) or a rewrite against /dev/mem. Until
then the RF chain must already be up when the script runs; the capture
and spectrum machinery works regardless of mixer state.

## Status

- [x] C app cross-compiles clean, both targets (aarch64 + armhf, static).
- [x] Python byte-compiles; FFT/peak and dt_find host-verified.
- [x] meta-fpgalab: uio-regs, fpgalab-py, fpgalab-image recipes written.
- [x] Recipes bitbake-verified: `uio-regs` compiles + packages with the
      image's own toolchain, `fpgalab-py` packages (rfsoc4x2/aarch64;
      recipes are arch-generic so blackboard follows with its image).
- [ ] On-target run (bench session: module 16 image + module 17/24
      bitstreams).

| Board | Status |
|---|---|
| blackboard | apps built; regs demos ready |
| rfsoc4x2 | apps built; regs + SDR capture ready |
| nexys4 | n/a - no PS, no Linux |
