REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
TOP := ipi_blinky_top

# First IP-integrator module: the block design is created by bd/*.tcl on
# the first build (wrapper auto-generated), the ILA by ip/*.tcl.
BD_TCL := bd/clkwiz_sys.tcl
IP_TCL := ip/debug_ila.tcl

# Clocked module: nexys4 and blackboard only (no rfsoc4x2 constraints on
# purpose - no free-running PL clock until Tier 5).
BOARD ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
