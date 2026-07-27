# CLAUDE.md

Project context for Claude Code sessions working in this repo. Read
`README.md` and `curriculum/README.md` too - this file is about *how to work
here*, not what the project is.

## What this is

A long-running, module-by-module FPGA/SoC/RFSoC learning journey across
three real boards (Nexys4, RealDigital BlackBoard Rev. D, RFSoC4x2). There is
no deadline and no fixed scope beyond "don't leave any concept behind" - see
`curriculum/README.md` for the full syllabus and current progress.
Treat this as an ongoing collaboration, not a one-shot task: expect to be
invoked repeatedly over weeks/months to build the next module, and pick up
from wherever `curriculum/README.md`'s checkboxes leave off.

## Tools

Vivado/Vitis 2026.1 live at `/opt/tools/2026.1`. `source env.sh` sets up
interactive use; the Makefiles source `settings64.sh` themselves per
invocation, so `make` alone never needs it. See `docs/tool_setup.md`.

**2026.1 facts that invalidate older muscle memory:** XSCT is disabled
(software builds go through the Vitis Python interface -
`common/tcl/build_app.py`, `make elf`) and there is no `vitis_hls` binary
(HLS is `v++ --mode hls` + `vitis-run` - `common/mk/hls.mk`, `make hls-*`).
`sdtgen` and `xsdb` still exist and are used.

**Embedded Linux is EDF (Yocto), not PetaLinux.** PetaLinux is EOL-bound and
was never installed here; Tier 6 uses the AMD Embedded Development
Framework - a plain Yocto workspace at `~/yocto/edf` (outside the repo: 50+
GB build trees, shared across boards/modules), all from public GitHub, no
license or installer. Flow: `make xsa` -> `sdtgen` -> `gen-machineconf
parse-sdt` -> `bitbake`. Never use gen-machine-conf's `parse-xsa` (deprecated
AND needs the disabled XSCT). Setup details in `docs/tool_setup.md`.

## Build system - read `docs/build_system.md` before touching Makefiles

The short version: every module is `hdl/` + `constraints/<board>.xdc` +
`Makefile` (includes `common/mk/common.mk` then `common/mk/vivado.mk`),
building into a gitignored `_out/<board>/vivado/` with a real `.xpr` inside.

**A bug worth not repeating:** `VIVADO := bash -c 'source ... && vivado'`
silently drops every argument appended after the quoted string (they become
positional params to the outer `bash -c`, not to `vivado`), so a "batch mode"
invocation launches the GUI instead with zero args and just sits there. The
fix already in `common/mk/vivado.mk`/`vitis.mk` is
`bash -c 'source ... && exec vivado "$$@"' vivado` - if you ever add another
tool wrapped this way, forward args the same way and check `vivado.log` for
`Command line : vivado -mode batch ...` (not bare `vivado` followed by
`start_gui`) after the first run.

**If a build fails with `Run 'synth_1' needs to be reset...` or similar lock
errors:** this usually means a previous run was killed mid-flight (e.g. a
timed-out shell command) leaving a stale run lock that `reset_run` can't
clear on its own. Fastest fix is `rm -rf _out/<board>` and rebuild from
scratch - artifacts are fully disposable by design.

**Licensing:** if Vivado refuses to launch at all with a license error, it's
almost always a node-locked license whose HOSTID doesn't match this
machine's actual Ethernet MAC (`ip link show`) - that's an AMD/Xilinx
licensing-portal fix, not a repo issue.

## Hardware truthfulness - the one hard rule

Never hand-type or guess an FPGA pin constraint from memory or by eyeballing
a schematic image. Every constraint currently in `boards/` was copied
verbatim from an official vendor repo (see each board's `docs/README.md` for
which one and how to refresh it). If a board or peripheral has no official
source, say so explicitly in the docs and leave it clearly marked
unverified/TODO rather than filling in a plausible-looking number - a wrong
pin constraint is a much more expensive mistake to chase down than an honest
gap. When adding a new board, follow `docs/build_system.md`'s "Adding a new
board" section.

This rule has caught real errors ("Nexys4" LED/switch pins recalled from
memory turned out to be the Nexys4-DDR's - module 27), and it extends
beyond pins: register values for board chips are vendored from official
repos (`boards/rfsoc4x2/rfclk/`), and **voltages count too** - module 29
ships no RFSoC4x2 variant because the Pmod+ signal-level question
(LVCMOS18 bank vs 3.3V connector Vdd, manual silent on shifting) is
unresolved; don't wire it to a 3.3V board until a schematic answers.

## Curriculum conventions

- Modules are numbered in learning order; each is self-contained and
  buildable on its own.
- Prefer the same HDL retargeted across all applicable boards over
  board-specific logic - the point of repeating a module per board is seeing
  identical RTL go through different constraints/parts, not writing three
  different designs.
- Update `curriculum/README.md`'s checkboxes as modules land.
- RFSoC4x2 has no PL fabric clock until the Zynq PS is configured
  (`curriculum/13_zynq_ps_bringup`); BlackBoard does have one (100MHz, pin
  H16). Nexys4 has one always. Keep this in mind before assuming a clocked
  design "just works" identically on all three.

## Persistent memory

Cross-session context about this project (decisions made, gotchas hit, where
things stand) is tracked in this assistant's own memory system, not in this
repo. Check it at the start of a session if picking up mid-journey.
