# Shared variables included by every module Makefile. Locate the repo root
# from this file's own path so module Makefiles work regardless of $(CURDIR).
COMMON_MK_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT      := $(abspath $(COMMON_MK_DIR)/../..)
COMMON_TCL_DIR := $(REPO_ROOT)/common/tcl

TOOLS_ROOT     ?= /opt/tools/2026.1
VIVADO_SETTINGS := $(TOOLS_ROOT)/Vivado/settings64.sh
VITIS_SETTINGS  := $(TOOLS_ROOT)/Vitis/settings64.sh

BOARD ?= nexys4
BOARD_DIR := $(REPO_ROOT)/boards/$(BOARD)
-include $(BOARD_DIR)/board.mk

# Make every vendored board_files dir visible to Vivado (board.repoPaths,
# consumed by common/tcl/build_project.tcl). This is what lets block
# automation apply real PS presets (DDR timings, MIO) from the vendored
# board definitions instead of hand-typing hundreds of PCW_*/PSU__* values.
export FPGA_LAB_BOARD_REPOS := $(wildcard $(REPO_ROOT)/boards/*/board_files)

OUT_DIR  ?= _out
PROJ_NAME ?= $(notdir $(patsubst %/,%,$(CURDIR)))

.PHONY: board-info
board-info:
	@echo "BOARD       = $(BOARD)"
	@echo "FPGA_PART   = $(FPGA_PART)"
	@echo "BOARD_PART  = $(BOARD_PART)"
	@echo "PROJ_NAME   = $(PROJ_NAME)"
	@echo "OUT_DIR     = $(OUT_DIR)"
