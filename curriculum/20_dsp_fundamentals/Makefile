REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

TOP     := fir4_transposed
HLS_TOP := fir4_hls
BOARD  ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/hls.mk

# make sim-all   - Verilog FIR vs Q1.15 reference model
# make ooc       - out-of-context synth: proves the DSP48 mapping
# make hls-csim / hls-synth / hls-cosim - the HLS twin
