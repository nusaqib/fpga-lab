---
name: fpga-build
description: Build, program, or inspect an fpga-lab module's Vivado bitstream across one or more boards. Use when the user asks to build/synthesize/program a module, check that it builds on all boards, or open a generated project in the GUI.
---

# Building fpga-lab modules

Quick reference for the actual commands - see `docs/build_system.md` for the
full explanation of what each one does and where output lands.

## Building

```sh
cd curriculum/<module>              # or projects/<name>
make BOARD=<nexys4|rfsoc4x2|blackboard> bitstream
```

To verify a module across every board it claims to support, run each
sequentially and check the tail of the output for `write_bitstream completed
successfully` / `Bitgen Completed Successfully` - don't assume success from
exit code alone if running through a wrapper that pipes output. Vivado
batch runs can take from under a minute to several minutes; for a first run
on a large device (RFSoC4x2), or when checking multiple boards back to back,
prefer running each in the background and waiting for the completion
notification rather than a long foreground wait.

## Common failure recovery

- **`Run 'synth_1' needs to be reset...` / any run-lock error**: usually a
  stale lock from a previously killed/interrupted build. Fix:
  `rm -rf _out/<board>` then rebuild - artifacts are fully disposable.
- **License errors at Vivado launch**: environment/licensing issue, not a
  repo problem - see `docs/build_system.md`'s licensing note.
- **Vivado seems to hang with no synth/impl output ever appearing**: check
  `_out/<board>/vivado/vivado.log`'s `Command line` entry - if it says just
  `vivado` with no `-mode batch`, the argument-forwarding bug documented in
  `CLAUDE.md` has regressed; check `common/mk/vivado.mk`'s `VIVADO` variable
  still uses `exec vivado "$$@"`.

## Other targets

```sh
make BOARD=<b> synth        # synthesis only
make BOARD=<b> gui           # open the generated .xpr in the Vivado GUI
make BOARD=<b> program       # push the bitstream over JTAG (board connected)
make BOARD=<b> board-info    # print resolved part/paths, no build
make BOARD=<b> clean         # wipe that board's _out/
make clean-all               # (repo root) wipe every module's _out/
```

Before committing any work in a module, run `make clean` (or `clean-all` at
the repo root) and check `git status` for stray `_out/`, `.xpr`, `.bit`,
`vivado.log`/`.jou`, or `.Xil/` files that shouldn't be tracked.
