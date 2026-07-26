REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
TOP := traffic_top

# Clocked module: nexys4 and blackboard only (no rfsoc4x2 constraints on
# purpose - no free-running PL clock until Tier 5).
BOARD ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
