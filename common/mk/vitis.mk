# Generic Vitis (unified) application build flow for Zynq/RFSoC modules,
# driven by common/tcl/build_app.tcl. A module Makefile sets XSA, APP_NAME,
# APP_TEMPLATE (or SRC_C) then does:
#   include $(REPO_ROOT)/common/mk/common.mk
#   include $(REPO_ROOT)/common/mk/vitis.mk
# (common.mk must be included first - this file relies on REPO_ROOT etc.)

# See the NB in vivado.mk - args must be forwarded via "$@", not appended
# after a `bash -c '...'` string, or they're silently dropped.
VITIS := bash -c 'source $(VITIS_SETTINGS) && exec xsct "$$@"' xsct

APP_NAME ?= $(PROJ_NAME)
XSA      ?= $(wildcard hw/$(BOARD)/*.xsa)
SRC_C    ?= $(wildcard src/*.c) $(wildcard src/*.cpp) $(wildcard src/*.h)

VITIS_WS_DIR := $(OUT_DIR)/$(BOARD)/vitis_ws
ELF          := $(VITIS_WS_DIR)/$(APP_NAME)/Debug/$(APP_NAME).elf

.PHONY: elf clean-vitis

elf: $(ELF)

$(ELF): $(SRC_C) $(XSA)
	@if [ -z "$(strip $(XSA))" ]; then echo "ERROR: no .xsa hardware platform found for BOARD=$(BOARD) - build the hardware module first"; exit 1; fi
	mkdir -p $(VITIS_WS_DIR)
	$(VITIS) $(COMMON_TCL_DIR)/build_app.tcl $(VITIS_WS_DIR) $(APP_NAME) "$(XSA)" "$(SRC_C)"

clean-vitis:
	rm -rf $(VITIS_WS_DIR)
