REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Zynq boards only. CPU follows the board for the software build.
BOARD ?= blackboard
TOP    := ps_gpio_$(BOARD)
BD_TCL := bd/ps_gpio_sys_$(BOARD).tcl
ifeq ($(BOARD),rfsoc4x2)
CPU := psu_cortexa53_0
else
CPU := ps7_cortexa9_0
endif

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

# Full flow per board:
#   make BOARD=<b> bitstream   # hardware
#   make BOARD=<b> xsa         # platform export
#   make BOARD=<b> elf         # bare-metal app (Vitis Python flow)
