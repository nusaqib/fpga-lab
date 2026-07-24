# fpga-lab

A from-scratch FPGA/SoC/RFSoC learning journey, driven module by module from
basic digital logic through Zynq PS bring-up, embedded Linux, HLS/DSP, and
RF data converters - targeting three real boards:

- **Digilent Nexys4** (Artix-7, `xc7a100tcsg324-1`) - pure-fabric logic, no PS.
- **RealDigital BlackBoard** (Zynq-7000, `xc7z007sclg400-1`) - smallest Zynq
  PS in the lineup.
- **RealDigital RFSoC4x2** (Zynq UltraScale+ RFSoC, `xczu48dr-ffvg1517-2-e`) -
  RF data converters, high-speed I/O, the deep end.

See **`curriculum/README.md`** for the full syllabus (30 modules, Tier 0
through Tier 10) and **`docs/build_system.md`** for how the scripted
Make/Tcl build flow works.

## Quickstart

```sh
source env.sh                        # sets up Vivado/Vitis 2026.1 on PATH
cd curriculum/00_first_bitstream
make bitstream                       # builds for BOARD=nexys4 by default
make BOARD=rfsoc4x2 bitstream
make program                         # push the bitstream over JTAG
make gui                             # open the generated .xpr in Vivado
```

Every build's artifacts (Vivado project, runs, reports, bitstream) land in a
gitignored `_out/<board>/` next to the module's sources - open the `.xpr`
whenever you want to poke around in the GUI, and `make clean` to wipe it.

## Repo layout

```
boards/<name>/        board.mk (part numbers), xdc/, board_files/, docs/
                       (manuals + vendored, verified upstream constraints)
common/mk/             shared Makefile includes (Vivado/Vitis build rules)
common/tcl/            shared Tcl scripts the Makefiles drive
curriculum/<NN_name>/  one module per concept, numbered in learning order
projects/              larger/capstone projects that don't fit "one concept"
docs/                  toolchain setup, build-system conventions
scripts/               vendor-file refresh helper
```

## Hardware truthfulness

Every pin constraint in `boards/` is copied verbatim from an official vendor
source: Digilent's `digilent-xdc`/`vivado-boards` for Nexys4, RealDigital's
`RFSoC4x2-BSP` for RFSoC4x2, and RealDigital's `linux-blackboard` for
BlackBoard Rev. D. Nothing is hand-transcribed off a schematic or guessed.
