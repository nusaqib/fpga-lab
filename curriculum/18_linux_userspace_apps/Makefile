REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)

# No hardware of its own: the regs demos run on module 17's design, the
# SDR capture on module 24's. This Makefile just cross-checks the code:
# cross-compiles the C app and byte-compiles the Python.
BOARD ?= blackboard
TOOLS_ROOT ?= /opt/tools/2026.1

ifeq ($(BOARD),rfsoc4x2)
CROSS_CC := $(TOOLS_ROOT)/Vitis/gnu/aarch64/lin/aarch64-linux/bin/aarch64-linux-gnu-gcc
else
CROSS_CC := $(TOOLS_ROOT)/Vitis/gnu/aarch32/lin/gcc-arm-linux-gnueabi/bin/arm-linux-gnueabihf-gcc
endif

APP_OUT := _out/$(BOARD)/app

.PHONY: all app py-check clean
all: app py-check

app: $(APP_OUT)/devmem_regs
$(APP_OUT)/devmem_regs: src/devmem_regs.c
	mkdir -p $(APP_OUT)
	$(CROSS_CC) -O2 -Wall -Wextra -static -o $@ $<
	@echo "app: $@ ($$(file -b $@ | cut -d, -f1-2))"

py-check:
	python3 -m py_compile py/uio.py py/blink.py py/sdr_capture.py
	@echo "python: OK"

clean:
	rm -rf _out __pycache__ py/__pycache__
