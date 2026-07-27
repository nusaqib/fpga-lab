# Persist "uio_pdrv_genirq claims our axil_regs peripheral" across boots
# by baking the of_id= parameter into /chosen bootargs (module 17).
#
# EXTRA_DT_INCLUDE_FILES is the device-tree recipe's official hook: each
# listed dtsi is copied next to the generated SDT and #include'd at the
# end of system-top.dts, so it can override earlier nodes.
#
# Inert unless the build opts in (local.conf: FPGALAB_UIO_DT = "1").
# The dtsi only touches /chosen bootargs, but changing the kernel command
# line of every machine in the shared workspace should be a choice, not a
# side effect of having the layer added.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

FPGALAB_UIO_DT ??= "0"
EXTRA_DT_INCLUDE_FILES:append:zynqmp = "${@' fpgalab-uio-zynqmp.dtsi' if d.getVar('FPGALAB_UIO_DT') == '1' else ''}"
EXTRA_DT_INCLUDE_FILES:append:zynq   = "${@' fpgalab-uio-zynq.dtsi'   if d.getVar('FPGALAB_UIO_DT') == '1' else ''}"
