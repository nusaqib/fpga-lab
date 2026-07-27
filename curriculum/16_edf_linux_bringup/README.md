# 16 - Embedded Linux bring-up with AMD EDF (Yocto)

**Goal:** boot a Linux we built ourselves on both Zynq boards, from our own
hardware design, understanding every artifact on the SD card. This tier was
originally scoped for PetaLinux; it uses **EDF** (AMD's Embedded Development
Framework) instead - see the tier note in `curriculum/README.md` and the
setup section in `docs/tool_setup.md` for why (short version: PetaLinux is
EOL-bound, EDF is plain upstream Yocto, and it needs no installer, license,
or AMD account).

## The chain, tool by tool

```
bd/ps_sys_<board>.tcl      the PS block design (module 13's, verbatim -
                           the preset from vendored board_files IS the
                           hardware truth Linux boots on)
   | make xsa
   v
<module>_<board>.xsa       hardware export, same as every Tier-5 module
   | sdtgen  (ships in Vitis - no XSCT involved)
   v
System Device Tree         system-top.dts + pcw.dtsi (the PS config as DT)
                           + pl.dtsi (fabric peripherals) + psu_init
   | gen-machineconf parse-sdt   (from meta-xilinx)
   v
Yocto MACHINE "rfsoc4x2"   conf/machine/rfsoc4x2.conf + FSBL/PMU-firmware
                           multiconfigs - bare-metal boot firmware built
                           from the same SDT, automatically
   | bitbake core-image-minimal xilinx-bootbin
   v
BOOT.BIN + kernel + rootfs
```

Every stage consumes the previous stage's output and nothing else - the
same XSA that fed `make elf` in Tier 5 feeds a whole operating system here.
The device tree is the star: it is to Linux what `xparameters.h` was to
bare metal, and you can read the lineage directly (`pcw.dtsi` carries the
identical preset values our vendored `board_files/` provided in module 13).

## Where things live

The Yocto workspace is **shared and outside the repo** at `~/yocto/edf`
(build trees run 50+ GB; `downloads/` and `sstate-cache/` are reused across
boards and modules - the one deliberate exception to the per-module `_out/`
convention). This module's `_out/` holds only the XSA and the generated SDT.

## Status

- [x] EDF 2026.1 workspace synced (`repo` manifest `rel-v2026.1`,
      `default-edf.xml`), bitbake environment sane.
- [x] XSA -> SDT proven (`sdtgen`, rfsoc4x2).
- [x] SDT -> MACHINE proven (`gen-machineconf`, `rfsoc4x2.conf` with
      cortexa53-fsbl + microblaze-pmu multiconfigs).
- [~] First `bitbake core-image-minimal xilinx-bootbin` for rfsoc4x2 in
      progress (first build compiles the cross-toolchain and kernel on two
      cores - hours; subsequent builds are incremental).
- [ ] Same for blackboard (`zynq` family path).
- [ ] SD card layout + boot on hardware, UART login.
- [ ] Makefile wrapping of the sdtgen/gen-machineconf/bitbake steps.

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | machine generated; first image building |
| blackboard | pending (same flow, `--soc-family zynq`) |
| nexys4 | n/a - no hard PS; its Linux story would be a soft-CPU one (module 30's MicroBlaze-V could run Linux, but that's beyond this tier's scope) |
