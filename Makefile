# Top-level convenience targets. Actual builds happen inside each module's
# own Makefile (curriculum/*/Makefile, projects/*/Makefile) - this file just
# fans out to them / does repo-wide housekeeping.
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MODULES   := $(sort $(dir $(wildcard $(REPO_ROOT)/curriculum/*/Makefile) $(wildcard $(REPO_ROOT)/projects/*/Makefile)))

.PHONY: help list clean-all distclean-all

help:
	@echo "fpga-lab top-level targets:"
	@echo "  make list          - list every buildable module"
	@echo "  make clean-all     - remove every module's _out/ build directory"
	@echo ""
	@echo "Per-module targets (run inside curriculum/<module>/ or projects/<name>/):"
	@echo "  make bitstream [BOARD=nexys4|rfsoc4x2|blackboard]"
	@echo "  make synth | make gui | make program | make clean | make board-info"

list:
	@for m in $(MODULES); do echo "$${m#$(REPO_ROOT)/}"; done

clean-all:
	@for m in $(MODULES); do $(MAKE) -C $$m clean; done

distclean-all: clean-all
