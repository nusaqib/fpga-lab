REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Two tops: fast_top (default - pipelined + MCP, meets timing) and
# slow_top (the deliberate failure, for reading a negative-slack report):
#   make TOP=slow_top BOARD=nexys4 bitstream
TOP ?= fast_top

# Clocked module: nexys4 and blackboard only (no rfsoc4x2 constraints on
# purpose - no free-running PL clock until Tier 5).
BOARD ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
