REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Same hardware as module 22 (that's the lesson - DUC/DDC is runtime
# configuration); all module-23 content is in src/main.c.
BOARD  ?= rfsoc4x2
TOP    := rfdc_sys_wrapper
BD_TCL := bd/rfdc_ddc_sys.tcl
CPU    := psu_cortexa53_0

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

#   make bitstream xsa elf   (BOARD defaults to rfsoc4x2)
