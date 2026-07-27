REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Tier 8 capstone: HLS DDS transmitter (Tier 7's flow) + RFDC loopback
# (module 22's hardware) + I/Q capture + FFT spectrum in C on the A53.
BOARD   ?= rfsoc4x2
HLS_TOP := dds_hls
HLS_PKG := ip_catalog
TOP     := rfdc_sys_wrapper
BD_TCL  := bd/sdr_sys.tcl
CPU     := psu_cortexa53_0

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk
include $(REPO_ROOT)/common/mk/hls.mk

# The BD script instantiates the packaged HLS IP from this path.
export FPGA_LAB_HLS_IP = $(abspath $(HLS_IP_DIR))
# Order-only: package the IP before the first bitstream build.
$(BIT): | hls-package

# hls/dds_tab.h is generated (scripts/gen_dds_tables.py) and checked in:
.PHONY: dds-tables
dds-tables:
	python3 $(REPO_ROOT)/scripts/gen_dds_tables.py hls/dds_tab.h

#   make bitstream xsa elf   (BOARD defaults to rfsoc4x2)
