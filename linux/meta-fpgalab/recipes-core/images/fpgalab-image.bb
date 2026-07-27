SUMMARY = "core-image-minimal plus the fpga-lab userspace (module 18)"
DESCRIPTION = "Everything module 16 boots, plus python3, the kernel \
modules (uio_pdrv_genirq lives there), and the curriculum's C/Python \
hardware tools. Build with: MACHINE=<board> bitbake fpgalab-image \
(and xilinx-bootbin, as ever, for BOOT.BIN)."
LICENSE = "MIT"

inherit core-image

IMAGE_INSTALL = "\
    packagegroup-core-boot \
    kernel-modules \
    python3 \
    uio-regs \
    fpgalab-py \
    ${CORE_IMAGE_EXTRA_INSTALL} \
"
