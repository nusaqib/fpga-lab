REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# RFSoC4x2 only: it's the one board here with Ethernet (GEM1 + DP83867
# on MIO - the BlackBoard has no Ethernet port, the Nexys4's PHY would
# need a fabric MAC + soft CPU). BSP_LIBS pulls lwIP into the platform.
BOARD    ?= rfsoc4x2
TOP      := eth_sys_wrapper
BD_TCL   := bd/eth_sys.tcl
CPU      := psu_cortexa53_0
BSP_LIBS := lwip220

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

#   make bitstream xsa elf   (BOARD defaults to rfsoc4x2)
