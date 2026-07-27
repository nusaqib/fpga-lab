# Generic Vitis (2026.1 unified) bare-metal application build flow, driven
# by common/tcl/build_app.py through the Vitis Python interface (XSCT is
# disabled in 2026.1). A module Makefile sets XSA, CPU (and optionally
# APP_NAME, SRC_DIR) then does:
#   include $(REPO_ROOT)/common/mk/common.mk
#   include $(REPO_ROOT)/common/mk/vivado.mk    (hardware side, provides xsa)
#   include $(REPO_ROOT)/common/mk/vitis.mk
# (common.mk must be included first - this file relies on REPO_ROOT etc.)

# Same "$@"-forwarding shape as the vivado wrapper (see vivado.mk's NB).
VITIS_RUN := bash -c 'source $(VITIS_SETTINGS) && exec vitis "$$@"' vitis

APP_NAME ?= $(PROJ_NAME)_app
CPU      ?= ps7_cortexa9_0
SRC_DIR  ?= src
XSA      ?= $(XSA_FILE)
# Optional comma-separated BSP libraries (e.g. lwip220), see build_app.py.
BSP_LIBS ?=

VITIS_WS := $(OUT_DIR)/$(BOARD)/vitis_ws
ELF      := $(VITIS_WS)/$(APP_NAME)/build/$(APP_NAME).elf

.PHONY: elf clean-vitis

elf: $(ELF)

$(ELF): $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/*.h) $(XSA)
	@if [ ! -f "$(XSA)" ]; then echo "ERROR: XSA not found: $(XSA) - run 'make BOARD=$(BOARD) xsa' first"; exit 1; fi
	$(VITIS_RUN) -s $(COMMON_TCL_DIR)/build_app.py "$(VITIS_WS)" "$(APP_NAME)" "$(XSA)" "$(CPU)" "$(SRC_DIR)" "$(BSP_LIBS)"
	@echo "ELF: $(ELF)"

clean-vitis:
	rm -rf $(VITIS_WS)
