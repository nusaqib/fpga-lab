REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Direct-sampling digital LLRF on the RFSoC4x2 - see DESIGN.md.
# RF plumbing (tile 2, DAC_A/ADC_A, 4.9152 GSPS) is module 24's, the
# LLRF logic is hdl/, the loop is proven in sim/ before it ever meets
# the converters.
BOARD  ?= rfsoc4x2
TOP    := llrf_sys_wrapper
BD_TCL := bd/llrf_sys.tcl
CPU    := psu_cortexa53_0

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

#   make sim-all             all testbenches (unit DSP, pulse gen, closed loop)
#   make bitstream xsa elf   hardware + bare-metal bring-up
