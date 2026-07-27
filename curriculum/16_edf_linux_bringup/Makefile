REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Hardware side: module 13's PS-only design, verbatim - the preset from
# the vendored board_files is exactly the hardware truth Linux boots on.
# Linux side: the EDF/Yocto chain (see common/mk/edf.mk and the README).
BOARD ?= rfsoc4x2
TOP    := ps_blinky_$(BOARD)
BD_TCL := bd/ps_sys_$(BOARD).tcl

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/edf.mk

#   make BOARD=<b> xsa sdt machine-conf image
#   (first `image` builds a cross-toolchain and kernel: hours on 2 cores)
