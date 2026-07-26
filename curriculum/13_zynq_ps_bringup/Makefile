REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# The two Zynq boards, side by side; top and BD script follow the board.
# Nexys4 has no PS - building it here is a configuration error, caught by
# the missing constraints/top (and this note).
BOARD ?= blackboard
TOP    := ps_blinky_$(BOARD)
BD_TCL := bd/ps_sys_$(BOARD).tcl

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk

# After `make BOARD=<b> bitstream`, export the Vitis hardware platform:
#   make BOARD=<b> xsa
