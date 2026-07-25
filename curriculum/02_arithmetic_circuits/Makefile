REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Six demos share this directory (adder_top, comparator_top, alu_add_top,
# alu_sub_top, alu_and_top, alu_or_top). Default to adder_top; override
# per build, e.g.:
#   make TOP=alu_sub_top BOARD=rfsoc4x2 bitstream
TOP ?= adder_top

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
