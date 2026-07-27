REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Hardware side: module 15's design verbatim (PS + our hand-written
# axil_regs AXI4-Lite slave) - this module is about what happens to that
# same peripheral on the LINUX side of the fence: the device-tree node
# sdtgen generates for it, and driving it through UIO instead of xil_io.
BOARD ?= blackboard
TOP    := ps_regs_$(BOARD)
BD_TCL := bd/ps_regs_sys_$(BOARD).tcl

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/edf.mk

#   make BOARD=<b> xsa sdt        # then read $(SDT_DIR)/pl.dtsi
#   make BOARD=<b> machine-conf image   # full Linux (shared EDF workspace)

# Cross-compile the UIO userspace driver with the Linux-targeting
# toolchains that ship inside Vitis (no Yocto SDK needed for a
# hello-world-sized app).
ifeq ($(BOARD),rfsoc4x2)
CROSS_CC := $(TOOLS_ROOT)/Vitis/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-gcc
else
CROSS_CC := $(TOOLS_ROOT)/Vitis/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-gcc
endif

APP_OUT := $(OUT_DIR)/$(BOARD)/app
.PHONY: app
app: $(APP_OUT)/uio_regs
$(APP_OUT)/uio_regs: src/uio_regs.c
	mkdir -p $(APP_OUT)
	$(CROSS_CC) -O2 -Wall -Wextra -static -o $@ $<
	@echo "app: $@ ($$(file -b $@ | cut -d, -f1-2))"
