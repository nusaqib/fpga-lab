REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# RFSoC4x2 only: this module IS the RF data converters. The BD wrapper is
# the top directly - every external port is a dedicated RF pin (analog
# vin/vout, RF refclks, sysref), so there is nothing for a hand-written
# top or a pin XDC to add.
BOARD  ?= rfsoc4x2
TOP    := rfdc_sys_wrapper
BD_TCL := bd/rfdc_loopback_sys.tcl
CPU    := psu_cortexa53_0

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

# src/rfclk_regs.h is generated from the vendored TICS register dumps
# (boards/rfsoc4x2/rfclk/) and checked in; regenerate after refreshing the
# vendored files:
.PHONY: rfclk-regs
rfclk-regs:
	python3 $(REPO_ROOT)/scripts/tics_to_header.py src/rfclk_regs.h \
	    LMK04828_REGS=$(REPO_ROOT)/boards/rfsoc4x2/rfclk/LMK04828_245.76.txt \
	    LMX2594_REGS=$(REPO_ROOT)/boards/rfsoc4x2/rfclk/LMX2594_491.52.txt

#   make bitstream xsa elf   (BOARD defaults to rfsoc4x2)
