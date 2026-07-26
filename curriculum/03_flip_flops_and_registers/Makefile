REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
TOP := capture_top

# First clocked module: nexys4 and blackboard only. RFSoC4x2 has no
# free-running PL clock until Zynq PS bring-up (Tier 5) - there is
# deliberately no constraints/rfsoc4x2.xdc here, so a BOARD=rfsoc4x2 build
# fails fast with the "no constraints found" error instead of producing
# something unusable.
BOARD ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
