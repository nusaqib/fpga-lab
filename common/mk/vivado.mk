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

VIVADO_PROJ_DIR := $(OUT_DIR)/$(BOARD)/vivado
XPR             := $(VIVADO_PROJ_DIR)/$(PROJ_NAME).xpr
BIT             := $(VIVADO_PROJ_DIR)/$(PROJ_NAME).runs/impl_1/$(TOP).bit

.PHONY: bitstream synth impl program gui clean distclean sim

bitstream: $(BIT)

$(BIT) $(XPR) &: $(SRC_V) $(XDC)
	@if [ -z "$(strip $(SRC_V))" ]; then echo "ERROR: SRC_V is empty - no HDL sources found"; exit 1; fi
	@if [ -z "$(strip $(XDC))" ]; then echo "ERROR: XDC is empty - no constraints found for BOARD=$(BOARD)"; exit 1; fi
	mkdir -p $(VIVADO_PROJ_DIR)
	$(VIVADO) -mode batch -source $(COMMON_TCL_DIR)/build_project.tcl \
		-tclargs $(PROJ_NAME) $(FPGA_PART) $(VIVADO_PROJ_DIR) "$(SRC_V)" "$(XDC)" $(TOP) "$(BOARD_PART)"

synth: $(XPR)
	$(VIVADO) -mode batch -source $(COMMON_TCL_DIR)/build_project.tcl \
		-tclargs $(PROJ_NAME) $(FPGA_PART) $(VIVADO_PROJ_DIR) "$(SRC_V)" "$(XDC)" $(TOP) "$(BOARD_PART)" synth_only

gui: $(XPR)
	$(VIVADO) $(XPR) &

program: $(BIT)
	$(VIVADO) -mode batch -source $(COMMON_TCL_DIR)/program.tcl -tclargs $(BIT)

clean:
	rm -rf $(OUT_DIR)

distclean: clean
