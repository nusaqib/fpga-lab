# Generic Vivado project-mode build flow, driven by common/tcl/build_project.tcl.
# A module Makefile sets SRC_V, XDC, TOP (and optionally BOARD) then does:
#   include $(REPO_ROOT)/common/mk/common.mk
#   include $(REPO_ROOT)/common/mk/vivado.mk
# (common.mk must be included first - this file relies on REPO_ROOT etc.)

# NB: `bash -c 'cmd' arg0 arg1...` passes arg1... to the script as $1... only
# if the script itself references "$@" - a bare `vivado` would silently
# ignore everything after it (and launch the GUI with no args at all).
VIVADO := bash -c 'source $(VIVADO_SETTINGS) && exec vivado "$$@"' vivado

TOP   ?= top
SRC_V ?= $(wildcard hdl/*.v) $(wildcard hdl/*.sv) $(wildcard hdl/*.vhd)
XDC   ?= $(wildcard constraints/$(BOARD)*.xdc)
# Optional IP-integrator hooks (see docs/build_system.md and module 10):
# BD_TCL - script creating block design(s); sourced on first build, wrapper
#          auto-generated. IP_TCL - script creating standalone IP; sourced
#          every build, must guard its own idempotency.
BD_TCL ?=
IP_TCL ?=

VIVADO_PROJ_DIR := $(OUT_DIR)/$(BOARD)/vivado
XPR             := $(VIVADO_PROJ_DIR)/$(PROJ_NAME).xpr
BIT             := $(VIVADO_PROJ_DIR)/$(PROJ_NAME).runs/impl_1/$(TOP).bit

# --- Simulation (xsim, standalone - no project needed) ---------------------
# Same "$@"-forwarding fix as VIVADO above.
XVLOG := bash -c 'source $(VIVADO_SETTINGS) && exec xvlog "$$@"' xvlog
XELAB := bash -c 'source $(VIVADO_SETTINGS) && exec xelab "$$@"' xelab
XSIM  := bash -c 'source $(VIVADO_SETTINGS) && exec xsim "$$@"' xsim

SIM_V   ?= $(wildcard sim/*.v)
# Only tb_*.v files are runnable testbench tops; other sim/*.v files (e.g.
# behavioral stubs for generated IP, see module 10) are compiled alongside
# but never elaborated as a top.
SIM_TB  ?= $(wildcard sim/tb_*.v)
# Default to the first testbench found so `make sim` works with zero extra
# arguments in the common case of one testbench per module; override with
# `make SIM_TOP=tb_other_thing sim` when there's more than one.
SIM_TOP ?= $(basename $(notdir $(firstword $(SIM_TB))))
SIM_DIR := $(OUT_DIR)/sim
SIM_SRC_ABS := $(abspath $(SRC_V))
SIM_TB_ABS  := $(abspath $(SIM_V))

.PHONY: bitstream synth impl program gui clean distclean sim sim-all

bitstream: $(BIT)

# -log/-journal keep Vivado's own log and journal inside the build dir
# instead of littering the module root (they're vendored per-invocation, not
# per-project, so they can't just live next to the .xpr on their own).
VIVADO_LOG_ARGS = -log $(VIVADO_PROJ_DIR)/vivado.log -journal $(VIVADO_PROJ_DIR)/vivado.jou

$(BIT) $(XPR) &: $(SRC_V) $(XDC) $(BD_TCL) $(IP_TCL)
	@if [ -z "$(strip $(SRC_V))" ]; then echo "ERROR: SRC_V is empty - no HDL sources found"; exit 1; fi
	@if [ -z "$(strip $(XDC))" ]; then echo "ERROR: XDC is empty - no constraints found for BOARD=$(BOARD)"; exit 1; fi
	mkdir -p $(VIVADO_PROJ_DIR)
	$(VIVADO) -mode batch $(VIVADO_LOG_ARGS) -source $(COMMON_TCL_DIR)/build_project.tcl \
		-tclargs $(PROJ_NAME) $(FPGA_PART) $(VIVADO_PROJ_DIR) "$(SRC_V)" "$(XDC)" $(TOP) "$(BOARD_PART)" "" "$(BD_TCL)" "$(IP_TCL)"

synth: $(XPR)
	$(VIVADO) -mode batch $(VIVADO_LOG_ARGS) -source $(COMMON_TCL_DIR)/build_project.tcl \
		-tclargs $(PROJ_NAME) $(FPGA_PART) $(VIVADO_PROJ_DIR) "$(SRC_V)" "$(XDC)" $(TOP) "$(BOARD_PART)" synth_only "$(BD_TCL)" "$(IP_TCL)"

gui: $(XPR)
	$(VIVADO) $(XPR) &

program: $(BIT)
	$(VIVADO) -mode batch $(VIVADO_LOG_ARGS) -source $(COMMON_TCL_DIR)/program.tcl -tclargs $(BIT)

# Hardware platform export for Vitis (Tier 5+): builds the bitstream if
# needed, then writes <module>_<board>.xsa next to the project.
XSA_FILE := $(VIVADO_PROJ_DIR)/$(PROJ_NAME)_$(BOARD).xsa
.PHONY: xsa
xsa: $(BIT)
	$(VIVADO) -mode batch $(VIVADO_LOG_ARGS) -source $(COMMON_TCL_DIR)/export_xsa.tcl \
		-tclargs $(XPR) $(XSA_FILE)
	@echo "XSA: $(XSA_FILE)"

clean:
	rm -rf $(OUT_DIR)

distclean: clean

# `make sim` (default testbench) or `make SIM_TOP=tb_other sim`. Compiles
# every hdl/*.v + sim/*.v together (xvlog), elaborates just SIM_TOP (xelab),
# then runs it to completion in batch mode (xsim -runall) - no waveform GUI,
# no project, just compile/elaborate/run like the lesson describes. Fails
# the build if the testbench printed "FAIL" anywhere (see sim/tb_*.v for the
# self-checking convention this relies on).
sim:
	@if [ -z "$(strip $(SIM_TOP))" ]; then echo "ERROR: no sim/*.v testbenches found - add one, or set SIM_TOP=<module>"; exit 1; fi
	mkdir -p $(SIM_DIR)
	cd $(SIM_DIR) && $(XVLOG) -sv $(SIM_SRC_ABS) $(SIM_TB_ABS)
	cd $(SIM_DIR) && $(XELAB) $(SIM_TOP) -s $(SIM_TOP)_sim --timescale 1ns/1ps
	cd $(SIM_DIR) && ( $(XSIM) $(SIM_TOP)_sim -runall > $(SIM_TOP).sim.log 2>&1 || true )
	@cat $(SIM_DIR)/$(SIM_TOP).sim.log
	@if grep -qi "FAIL" $(SIM_DIR)/$(SIM_TOP).sim.log; then \
		echo ">>> SIMULATION FAILED - see $(SIM_DIR)/$(SIM_TOP).sim.log"; exit 1; \
	else \
		echo ">>> Simulation PASSED ($(SIM_TOP))"; \
	fi

# Run every tb_*.v under sim/ one at a time, stopping at the first failure.
sim-all:
	@for tb in $(basename $(notdir $(SIM_TB))); do \
		echo "=== $$tb ==="; \
		$(MAKE) SIM_TOP=$$tb sim || exit 1; \
	done
