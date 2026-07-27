REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Nexys4 only: it has the on-board ADT7420 wired to PL pins. (The Zynq
# boards' I2C devices hang off the PS - that's modules 14/15 territory.)
BOARD ?= nexys4
TOP    := temp_top

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk

#   make sim-all ; make bitstream program  (terminal at 115200)
