REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# RFSoC4x2 only: it has the GTY transceivers (100G QSFP28 cage). IBERT is
# a pure-PL debug design - no PS, no software, all interaction through
# the Hardware Manager's Serial I/O Analyzer.
BOARD  ?= rfsoc4x2
TOP    := ibert_qsfp_top
IP_TCL := ip/ibert_qsfp.tcl

include $(REPO_ROOT)/common/mk/common.mk
include $(REPO_ROOT)/common/mk/vivado.mk

#   make bitstream ; make program ; then Vivado HW manager -> Serial I/O
