# Generic Vitis HLS build flow (2026.1 unified: there is no vitis_hls
# binary anymore - C synthesis runs through `v++ --mode hls` and
# simulations through `vitis-run --mode hls`). A module Makefile sets
# HLS_TOP (and optionally HLS_CLK_NS) then does:
#   include $(REPO_ROOT)/common/mk/common.mk
#   include $(REPO_ROOT)/common/mk/vivado.mk    (if it also builds hardware)
#   include $(REPO_ROOT)/common/mk/hls.mk
#
# Expected module layout: hls/$(HLS_TOP).cpp (+ any headers) as the
# synthesizable source, hls/tb_$(HLS_TOP).cpp as the self-checking C
# testbench (prints PASS/FAIL like every other bench in this repo).

VPP       := bash -c 'source $(VITIS_SETTINGS) && exec v++ "$$@"' v++
VITISRUN  := bash -c 'source $(VITIS_SETTINGS) && exec vitis-run "$$@"' vitis-run

HLS_TOP    ?= top
HLS_CLK_NS ?= 10
HLS_PKG    ?= rtl
HLS_SRC    ?= hls/$(HLS_TOP).cpp
HLS_TB     ?= hls/tb_$(HLS_TOP).cpp

HLS_DIR  := $(OUT_DIR)/hls/$(BOARD)/$(HLS_TOP)
HLS_CFG  := $(HLS_DIR).cfg
HLS_RTL  := $(HLS_DIR)/hls/impl/verilog/$(HLS_TOP).v
HLS_RPT  := $(HLS_DIR)/hls/syn/report/$(HLS_TOP)_csynth.rpt

.PHONY: hls-synth hls-csim hls-cosim hls-report clean-hls

# Config is generated, not checked in: the part number must follow BOARD.
$(HLS_CFG): $(HLS_SRC) $(HLS_TB)
	@mkdir -p $(dir $@)
	@{ echo "part=$(FPGA_PART)"; \
	   echo ""; \
	   echo "[hls]"; \
	   echo "flow_target=vivado"; \
	   echo "syn.file=$(abspath $(HLS_SRC))"; \
	   echo "syn.top=$(HLS_TOP)"; \
	   echo "tb.file=$(abspath $(HLS_TB))"; \
	   echo "clock=$(HLS_CLK_NS)ns"; \
	   echo "package.output.format=$(HLS_PKG)"; } > $@

$(HLS_RTL): $(HLS_CFG)
	$(VPP) -c --mode hls --config $(HLS_CFG) --work_dir $(HLS_DIR)

hls-synth: $(HLS_RTL)
	@echo "HLS RTL: $(HLS_RTL)"

hls-csim: $(HLS_CFG)
	$(VITISRUN) --mode hls --csim --config $(HLS_CFG) --work_dir $(HLS_DIR) 2>&1 | tee $(HLS_DIR).csim.log
	@if grep -q "CSim done with 0 errors" $(HLS_DIR).csim.log && grep -q "PASS" $(HLS_DIR).csim.log; then \
		echo ">>> HLS C-simulation PASSED ($(HLS_TOP))"; \
	else \
		echo ">>> HLS C-SIMULATION FAILED - see $(HLS_DIR).csim.log"; exit 1; \
	fi

# RTL co-simulation: reruns the same C testbench against the GENERATED
# VERILOG in xsim - the HLS equivalent of "trust, but simulate".
hls-cosim: $(HLS_RTL)
	$(VITISRUN) --mode hls --cosim --config $(HLS_CFG) --work_dir $(HLS_DIR) 2>&1 | tee $(HLS_DIR).cosim.log
	@if grep -q "C/RTL co-simulation finished: PASS" $(HLS_DIR).cosim.log; then \
		echo ">>> HLS co-simulation PASSED ($(HLS_TOP))"; \
	else \
		echo ">>> HLS CO-SIMULATION FAILED - see $(HLS_DIR).cosim.log"; exit 1; \
	fi

hls-report: $(HLS_RTL)
	@sed -n '1,60p' $(HLS_RPT)

# Package the synthesized kernel as a Vivado IP (set HLS_PKG=ip_catalog in
# the module Makefile) - the output dir becomes an ip_repo_paths entry for
# BD scripts to instantiate from.
HLS_IP_DIR := $(HLS_DIR)/hls/impl/ip
.PHONY: hls-package
hls-package: $(HLS_RTL)
	$(VITISRUN) --mode hls --package --config $(HLS_CFG) --work_dir $(HLS_DIR)
	@ls $(HLS_IP_DIR)/component.xml >/dev/null 2>&1 && echo "HLS IP: $(HLS_IP_DIR)" \
		|| { echo "ERROR: packaged IP not found under $(HLS_IP_DIR)"; exit 1; }

clean-hls:
	rm -rf $(OUT_DIR)/hls
