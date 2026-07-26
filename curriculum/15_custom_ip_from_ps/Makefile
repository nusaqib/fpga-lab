REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

BOARD ?= blackboard
TOP    := ps_regs_$(BOARD)
BD_TCL := bd/ps_regs_sys_$(BOARD).tcl
ifeq ($(BOARD),rfsoc4x2)
CPU := psu_cortexa53_0
else
CPU := ps7_cortexa9_0
endif

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

#   make BOARD=<b> bitstream xsa elf
