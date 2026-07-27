REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Simulation-only module: verification methodology has no pins. (The
# .sv override below is why these can't rely on vivado.mk's *.v globs.)
SIM_V  := $(wildcard sim/*.v) $(wildcard sim/*.sv)
SIM_TB := $(wildcard sim/tb_*.v) $(wildcard sim/tb_*.sv)

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk

#   make sim-all   (there is deliberately no bitstream here)
