---
name: new-fpga-module
description: Scaffold a new curriculum (or projects/) module in fpga-lab following the repo's established Makefile/Tcl/board-constraints conventions. Use when the user asks to add, start, or create the next curriculum module or a new project.
---

# Scaffolding a new fpga-lab module

Follow this when asked to create a new module under `curriculum/` or
`projects/`. Read `docs/build_system.md` and an existing module (start with
`curriculum/00_first_bitstream/`) first if you haven't already - this skill
assumes you know that layout.

## Steps

1. **Confirm scope against the syllabus.** If this is a numbered curriculum
   module, check `curriculum/README.md` for its intended concept, which
   boards it targets, and what the module before it assumed. Don't skip the
   syllabus's own notes about board applicability (e.g. RFSoC4x2 has no PL
   clock before Tier 5 - see that file's "Board applicability" table).

2. **Create the directory:**
   ```
   curriculum/<NN>_<name>/
     README.md          # concept explanation, why it matters, what to look at after building
     hdl/                # board-agnostic sources where possible
     constraints/        # constraints/<board>.xdc per targeted board
     Makefile
   ```
   The `Makefile` is almost always exactly this shape (see
   `curriculum/00_first_bitstream/Makefile`):
   ```make
   REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
   TOP := <top_module_name>

   include $(REPO_ROOT)/common/mk/common.mk
   include $(REPO_ROOT)/common/mk/vivado.mk
   ```
   Only add `SRC_V`/`XDC` overrides if the defaults (`hdl/*.v`,
   `constraints/$(BOARD)*.xdc`) don't fit.

3. **Write the constraints per board from the vendored master files**, not
   from memory - copy the exact `PACKAGE_PIN`/`IOSTANDARD` lines out of
   `boards/<board>/xdc/*Master*.xdc` (or the per-peripheral files for
   RFSoC4x2), renaming ports to match your HDL's port names. Never invent a
   pin. If a board's master XDC doesn't cover a signal you need, that's a
   sign the board doesn't support this exercise yet, not a cue to guess.

4. **Build and verify on every board the module claims to support** before
   calling it done:
   ```sh
   cd curriculum/<NN>_<name>
   make BOARD=nexys4 bitstream
   make BOARD=rfsoc4x2 bitstream
   make BOARD=blackboard bitstream
   ```
   A module isn't finished until these actually succeed - "should work" isn't
   good enough, the whole point of this repo is real hardware verification.
   If a board can't build (missing clock, unsupported peripheral, etc.),
   note that explicitly in the module's README's "Board status" table rather
   than silently omitting it.

5. **Write the README** covering: what the design does, why it's structured
   this way, any board-specific gotchas, and a short "what to look at
   afterwards" pointing at specific Vivado GUI panels/reports worth opening.
   Follow `curriculum/00_first_bitstream/README.md`'s structure.

6. **Update `curriculum/README.md`**: flip the module's checkbox, and update
   the "Board applicability" table if this module changes what's possible
   (e.g. a module that finally unblocks RFSoC4x2 clocking).

7. **Clean before committing**: `make clean` (or `clean-all` from the repo
   root) so `_out/` and stray `vivado.log`/`.jou`/`.Xil` litter don't get
   accidentally staged. Check `git status` for anything under `_out/` or
   loose Vivado log files before `git add`.
