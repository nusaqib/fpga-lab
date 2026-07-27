REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# The capstone: a full RISC-V SoC in the Nexys4's fabric. The software
# flow is the same vitis.mk used since module 14 - just with a CPU that
# didn't exist until synthesis.
BOARD ?= nexys4
TOP    := riscv_soc_top
BD_TCL := bd/riscv_soc.tcl
CPU    := microblaze_riscv_0

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/vitis.mk

#   make bitstream xsa elf ; make program ; terminal at 115200 -> riscv>
