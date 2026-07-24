REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Four demos share this directory (gates_top, mux_top, decoder_top,
# priority_encoder_top). Default to gates_top; override per build, e.g.:
#   make TOP=decoder_top BOARD=rfsoc4x2 bitstream
TOP ?= gates_top

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
