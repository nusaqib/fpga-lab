REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Two boards, same RTL: only the top (ID + pin names) differs.
#   make BOARD=nexys4 bitstream ; make BOARD=blackboard bitstream
BOARD ?= nexys4
TOP    := link_top_$(BOARD)

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
