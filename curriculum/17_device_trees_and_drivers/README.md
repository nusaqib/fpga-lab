# 17 - Device trees & drivers: our peripheral meets the kernel

**Goal:** take module 15's hand-written `axil_regs` AXI4-Lite slave -
unchanged - and drive it from Linux instead of bare metal. Bare metal
talked to it through `Xil_Out32` at an address copied from
`xparameters.h`; Linux refuses to let userspace touch physical addresses,
and the kernel doesn't know our peripheral exists. This module is about
the two mechanisms that fix that: the **device tree** (how the kernel
learns the hardware exists) and a **driver** (how userspace gets a
sanctioned handle to it) - here UIO, the minimal "driver that lets
userspace be the driver".

Hardware is `bd/`, `hdl/`, `constraints/` from module 15, verbatim. What's
new is everything after `make xsa`.

## The device tree is the star

Run the chain and read what falls out:

```sh
make BOARD=blackboard xsa sdt
cat _out/blackboard/sdt/pl.dtsi
```

sdtgen turns the XSA's address map into a device-tree node - this is the
actual output, not an example:

```dts
axil_regs_0: axil_regs@43c00000 {
        compatible = "xlnx,axil-regs-1.0";
        reg = <0x43c00000 0x10000>;
        clocks = <&clkc 15>;
        ...
};
```

Read the lineage: `reg` is the base/size we pinned in the block design
(0x43C00000 on BlackBoard, 0xA0000000 with 64-bit address cells on
RFSoC4x2), `compatible` is synthesized from our Verilog module's name, and
`clocks` points at the PS fabric clock feeding `aclk`. Everything module
14 read out of `xparameters.h` is here, but as a **description the kernel
parses at boot** instead of constants compiled into the app. That's the
whole idea: one binary kernel, hardware described as data.

## UIO: the smallest possible driver

No kernel driver claims `xlnx,axil-regs-1.0` (of course - we invented the
peripheral). Options, in increasing effort: poke `/dev/mem` (no driver at
all - module 18 shows it and why it's a last resort), **UIO** (this
module), or a real custom kernel module (deferred; UIO covers everything a
register-poke peripheral needs, interrupts included).

`uio_pdrv_genirq` is a generic platform driver with a boot-time parameter
`of_id=<compatible>` telling it which device-tree nodes to claim. Each
claimed node becomes `/dev/uioN` plus a sysfs directory
(`/sys/class/uio/uioN/maps/map0/{addr,size}`) exposing the reg window,
which userspace then `mmap`s. Two ways to point it at our node:

1. **Runtime, nothing persistent** (first-contact debugging):
   `modprobe uio_pdrv_genirq of_id=xlnx,axil-regs-1.0`
   (works when the driver is a module; check with
   `zcat /proc/config.gz | grep UIO_PDRV_GENIRQ`)
2. **Baked into the boot** - kernel command line via `/chosen` bootargs.
   `linux/meta-fpgalab/` (this repo's own Yocto layer, new in this module)
   carries a `device-tree.bbappend` that appends a dtsi through the
   recipe's official `EXTRA_DT_INCLUDE_FILES` hook. It's opt-in - set
   `FPGALAB_UIO_DT = "1"` in `local.conf` - because silently changing the
   kernel command line for every machine in the shared workspace would be
   rude.

Note what we did NOT do: the widespread hack is to override the node's
`compatible` to `"generic-uio"` in a user dtsi. It works (that's the
default `of_id`), but it replaces the truthful description of what the
hardware IS with the name of the driver you happen to want - the DT
equivalent of hand-editing a pin constraint. `of_id=xlnx,axil-regs-1.0`
achieves the same binding with the description intact.

## The userspace driver

`src/uio_regs.c` (cross-compiled by `make BOARD=<b> app` with the
Linux-targeting gcc that ships inside Vitis):

- finds our device by scanning `/sys/class/uio/*/name` - no hardcoded
  `/dev/uio0`, and, pointedly, **no hardcoded 0xA0000000**: the physical
  address travels BD -> device tree -> kernel -> sysfs;
- `mmap`s map0 of `/dev/uioN` and verifies the ID register
  (`0xF19A1AB0`) before touching anything else;
- then does exactly what module 15's bare-metal `main.c` did: scratch
  write/readback, live switch/button STATUS reads, LED walk.

## Build & run

```sh
make BOARD=blackboard xsa sdt app     # + machine-conf image for the OS itself
make BOARD=rfsoc4x2  xsa sdt app
```

On the booted board (module 16's image + this module's bitstream):

```sh
modprobe uio_pdrv_genirq of_id=xlnx,axil-regs-1.0
./uio_regs            # uio0: name="axil_regs" phys=0x43c00000 size=0x10000 ...
```

## Status

- [x] Hardware (module 15's, verbatim) rebuilt: bitstream + XSA, both boards.
- [x] SDT generated for both boards; `pl.dtsi` node verified against the
      BD address map (0x43C00000 / 0xA0000000, 64K, right clocks).
- [x] `meta-fpgalab` layer: opt-in bootargs dtsi via
      `EXTRA_DT_INCLUDE_FILES` (values restate sdtgen's real output).
- [x] `uio_regs` cross-compiles clean for both targets (aarch64 + armhf,
      static).
- [ ] On-target run (needs module 16's image booted; bench session).

| Board | Status |
|---|---|
| blackboard | built: bitstream, XSA, SDT, app |
| rfsoc4x2 | built: bitstream, XSA, SDT, app |
| nexys4 | n/a - no PS, no Linux |
