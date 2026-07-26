REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# Pure HLS module: no hdl/, no constraints/ - hardware integration of the
# generated IP is module 21's job. Part number still follows BOARD so the
# RTL is generated for real silicon.
HLS_TOP := axis_scaler_hls
BOARD  ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/hls.mk

# make hls-csim    - C testbench against the C++ (fast, function only)
# make hls-synth   - C -> RTL, reports in _out/hls/<board>/<top>/hls/syn/report/
# make hls-cosim   - same testbench against the GENERATED VERILOG in xsim
# make hls-report  - print the csynth summary
