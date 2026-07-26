REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# HLS dataflow kernel + hardware integration into module 12's stream
# infrastructure (button -> src -> HLS IP -> capture, observed over JTAG).
HLS_TOP := fir_decim_hls
HLS_PKG := ip_catalog
TOP     := hls_pipe_top
BD_TCL  := bd/hls_pipe_sys.tcl
BOARD  ?= nexys4

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk
include $(REPO_ROOT)/common/mk/hls.mk

# The BD script instantiates the packaged HLS IP from this path.
export FPGA_LAB_HLS_IP = $(abspath $(HLS_IP_DIR))
# Order-only: package the IP before the first bitstream build (phony
# prerequisite would force a rebuild every run; order-only doesn't).
$(BIT): | hls-package
