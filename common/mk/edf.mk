# Embedded Linux (AMD EDF / Yocto) flow, introduced in module 16. A module
# Makefile includes this AFTER common.mk and vivado.mk (it consumes the
# XSA_FILE those define):
#
#   make BOARD=<b> xsa            # hardware export (vivado.mk, as ever)
#   make BOARD=<b> sdt            # XSA -> System Device Tree (sdtgen)
#   make BOARD=<b> machine-conf   # SDT -> Yocto MACHINE (gen-machineconf)
#   make BOARD=<b> image          # bitbake the boot firmware + rootfs
#
# The Yocto workspace is SHARED and lives outside the repo (50+ GB build
# trees, downloads/sstate reused across boards and modules) - see
# docs/tool_setup.md for the one-time bootstrap. Only the SDT lands in the
# module's _out/.

EDF_HOME  ?= $(HOME)/yocto/edf
EDF_BUILD ?= $(EDF_HOME)/build
# Yocto machine name; BOARD works because our board names are valid machine
# names and gen-machine-conf auto-detects the SoC family from the SDT.
MACHINE   ?= $(BOARD)
# What bitbake builds; xilinx-bootbin adds BOOT.BIN assembly.
EDF_IMAGE ?= core-image-minimal xilinx-bootbin

SDT_DIR := $(OUT_DIR)/$(BOARD)/sdt

# Same "$@"-forwarding shape as the vivado wrapper (see vivado.mk's NB).
SDTGEN  := bash -c 'source $(VITIS_SETTINGS) && exec sdtgen "$$@"' sdtgen
# edf-init-build-env must be sourced from its own directory and cd's into
# the build dir; everything EDF runs behind it.
EDF_ENV := cd $(EDF_HOME) && . ./edf-init-build-env $(EDF_BUILD) > /dev/null &&

.PHONY: sdt machine-conf image edf-info

$(SDT_DIR)/system-top.dts: $(XSA_FILE)
	@if [ ! -f "$(XSA_FILE)" ]; then echo "ERROR: XSA not found: $(XSA_FILE) - run 'make BOARD=$(BOARD) xsa' first"; exit 1; fi
	mkdir -p $(SDT_DIR)
	$(SDTGEN) -xsa $(abspath $(XSA_FILE)) -dir $(abspath $(SDT_DIR))

sdt: $(SDT_DIR)/system-top.dts

machine-conf: $(SDT_DIR)/system-top.dts
	@if [ ! -f "$(EDF_HOME)/edf-init-build-env" ]; then echo "ERROR: EDF workspace not found at $(EDF_HOME) - see docs/tool_setup.md"; exit 1; fi
	bash -c '$(EDF_ENV) gen-machineconf --hw-description $(abspath $(SDT_DIR)) -c conf --machine-name $(MACHINE)'

image: machine-conf
	bash -c '$(EDF_ENV) MACHINE=$(MACHINE) bitbake $(EDF_IMAGE)'
	@echo "images: $(EDF_BUILD)/tmp/deploy/images/$(MACHINE)/"

edf-info:
	@echo "EDF_HOME  = $(EDF_HOME)"
	@echo "MACHINE   = $(MACHINE)"
	@echo "SDT_DIR   = $(SDT_DIR)"
	@echo "EDF_IMAGE = $(EDF_IMAGE)"
	@echo "deploy    = $(EDF_BUILD)/tmp/deploy/images/$(MACHINE)/"
