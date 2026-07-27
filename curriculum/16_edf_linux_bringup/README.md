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

## SD card & boot (what actually lands on the card)

The first rfsoc4x2 build produced, in
`~/yocto/edf/build/tmp/deploy/images/rfsoc4x2/`: `boot.bin` (FSBL + PMU
firmware + ATF + u-boot + our PSU config, assembled by `xilinx-bootbin`),
`boot.scr`, kernel `Image` (linux-xlnx 6.18), `system.dtb`, and the
rootfs as `.tar.gz` / cpio variants.

How boot actually flows (read from the shipped `boot.scr`, which comes
from meta-amd-edf's `u-boot-edf-scr`): BootROM loads `BOOT.BIN` from the
first FAT partition -> u-boot runs `boot.scr` -> kernel is ext4load'ed
from **partition 3**, path `/boot/Image` (it lives inside the rootfs) ->
the device tree is the one already inside BOOT.BIN (`fdtcontroladdr` -
NOT loaded from disk) -> bootargs are read from that DT's `/chosen` (so
module 17's dtsi tweaks propagate) plus `root=PARTUUID=<p3> ro rootwait`.

The matching card layout is EDF's official wks
(`edf-disk-single-rootfs.wks`): **p1** 1G vfat (BOOT.BIN, boot.scr,
Image, dtb via IMAGE_BOOT_FILES), **p2** 2G vfat scratch storage, **p3**
ext4 rootfs. EDF doesn't emit a flashable image by default (only a
QEMU-shaped wic), so our shared `local.conf` appends
`IMAGE_FSTYPES:append = " wic"` + `WKS_FILE = "edf-disk-single-rootfs.wks"`;
then it's one `dd` of the `.wic` to the card.

## Status

- [x] EDF 2026.1 workspace synced (`repo` manifest `rel-v2026.1`,
      `default-edf.xml`), bitbake environment sane.
- [x] XSA -> SDT proven (`sdtgen`, both boards).
- [x] SDT -> MACHINE proven (`gen-machineconf`, `rfsoc4x2.conf` with
      cortexa53-fsbl + microblaze-pmu multiconfigs).
- [x] Makefile wrapping of the whole chain (`common/mk/edf.mk`, new):
      `make BOARD=<b> xsa sdt machine-conf image`.
- [x] First `bitbake core-image-minimal xilinx-bootbin` for rfsoc4x2
      **succeeded** (9975 tasks, 0 failures, ~1h45m - AMD's public
      sstate mirror carried most of the cross-toolchain).
- [x] Boot flow + SD layout traced from the real artifacts (above);
      flashable wic enabled in local.conf.
- [x] Same for blackboard (`zynq` family path): machine conf generated
      (cortexa9-fsbl multiconfig), image build succeeded (7727 tasks, 0
      failures - sstate reuse made the second board far cheaper), uImage
      + BOOT.BIN + flashable 3.2G `.wic` in the EDF layout.
- [ ] Boot on hardware, UART login (bench: `dd` the `.wic`, console
      115200 8N1 on the USB-UART).

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | image + BOOT.BIN + wic built; awaiting SD + bench |
| blackboard | image + BOOT.BIN + wic built; awaiting SD + bench |
| nexys4 | n/a - no hard PS; its Linux story would be a soft-CPU one (module 30's MicroBlaze-V could run Linux, but that's beyond this tier's scope) |
