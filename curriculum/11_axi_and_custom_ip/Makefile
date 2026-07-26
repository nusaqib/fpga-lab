REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
TOP := axil_demo_top

# The block design (JTAG-to-AXI master -> axil_regs as an RTL module
# reference) is created by bd/jtag_axi_sys.tcl on the first build.
BD_TCL := bd/jtag_axi_sys.tcl

# Clocked module: nexys4 and blackboard only (no rfsoc4x2 constraints on
# purpose - no free-running PL clock until Tier 5).
BOARD ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
