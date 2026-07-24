---
name: add-fpga-board
description: Onboard a new FPGA/SoC board into fpga-lab's boards/ directory with vendor-verified part numbers and pin constraints. Use when the user wants to add support for a new board, or asks to verify/fix an existing board's constraints.
---

# Adding (or fixing) board support

This encodes the process actually used to onboard Nexys4, RFSoC4x2, and
BlackBoard - including the two dead ends and the eventual fix for
BlackBoard, which is the cautionary tale this skill exists to prevent
repeating.

## The hard rule

**Never hand-type a PACKAGE_PIN from memory, and never transcribe one off a
schematic image/PDF by eye if you can possibly avoid it.** Schematic bank
tables pack (IO pin name / ball / net name) into dense multi-column layouts
that are genuinely easy to misread, and a wrong pin constraint is a much more
expensive mistake to debug on real hardware than an honest "not verified
yet" gap. Getting a board's manufacturer/model right (not a similarly-named
board) matters just as much - confirm hardware revision with the user if a
board line has multiple revisions with different pinouts (this happened with
BlackBoard Rev. D vs earlier revisions).

## Steps

1. **Identify the board precisely.** Manufacturer, exact model, and hardware
   revision if the line has more than one (ask the user if unsure - don't
   guess between similarly-named boards).

2. **Find an official, machine-readable source of pins - in this order of
   preference:**
   - A vendor GitHub repo with actual Vivado **board_files** (`board.xml` +
     `part0_pins.xml` + `preset.xml`) - the gold standard, gives you both the
     exact part string and a `board_part` id for `set_property board_part`.
   - A vendor GitHub repo with a real **master XDC** or per-peripheral `.xdc`
     files (even without board_files).
   - **Don't stop at the first repo that looks plausible.** The obvious
     top-level org repo isn't always the right one - for BlackBoard, the
     first repo found (`RealDigitalOrg/Blackboard`) turned out to ship only
     prebuilt bitstreams/Vitis platforms with no XDC at all; the real
     constraints lived in a *different* repo
     (`RealDigitalOrg/linux-blackboard`) found by searching for the board's
     Linux/PetaLinux BSP instead. If board_files/XDC aren't where you'd
     expect, check: the vendor's Linux/PetaLinux BSP repo, a "-BSP" or
     "-Vivado" suffixed repo, GitHub Release assets (sometimes a platform
     `.zip`/`.xsa` export contains real HW project sources - unzip and check
     before assuming a release asset is binary-only).
   - A reference manual or schematic PDF, read directly (via the `Read` tool,
     which renders PDF pages as images) - **last resort only**, and treat
     every pin read this way as unverified until cross-checked, because dense
     schematic tables are easy to misread. Trace signal names end-to-end
     (oscillator -> net name -> ball) rather than trusting a single glance at
     a row.

3. **Verify the part number matches Vivado's exact naming.** Datasheet-style
   notation (e.g. `XCZU48DR-1FFVG1517E`) and Vivado's part-string format
   (e.g. `xczu48dr-ffvg1517-2-e`) are NOT always trivially interchangeable -
   speed grade position and package string can differ. Trust the string from
   an actual `board.xml`/board_files over one assembled by hand from a
   datasheet.

4. **Vendor the files** (don't just link to them - see
   `boards/<board>/docs/README.md` in existing boards for the pattern):
   - `boards/<name>/xdc/` - the real XDC file(s), verbatim, plus the
     upstream's license file if one exists.
   - `boards/<name>/board_files/<name>/<version>/` - board_files if found.
   - `boards/<name>/docs/` - reference manuals/schematics if you fetched
     them, plus a `README.md` with the spec table, what's vendored, sourcing
     notes, and any board-specific gotchas (e.g. clocking availability for
     PL-only designs on Zynq boards - see `boards/rfsoc4x2/docs/README.md`
     and `boards/blackboard/docs/README.md`).

5. **Write `boards/<name>/board.mk`:**
   ```make
   FPGA_PART  := <exact part string from board_files or a verified source>
   BOARD_PART := <vendor:name:part0:version, if board_files exist - else leave blank>
   ```

6. **Add this board's refresh commands to `scripts/fetch_vendor_files.sh`**
   so the vendored copy can be re-synced later.

7. **Verify end to end**: build `curriculum/00_first_bitstream` (or the
   simplest existing module) against the new board with
   `make BOARD=<name> bitstream` and confirm a real bitstream comes out
   before calling the board "ready" anywhere in the docs.

## If you already got something wrong

This has happened before and isn't a big deal to fix: if a better upstream
source turns up after a board was already vendored with hand-derived/draft
pins (exactly what happened with BlackBoard), replace the draft file
entirely, update `board.mk`, and scrub "unverified"/"draft" language from
every doc that mentioned the gap (board's own README, that module's README
board-status table, `curriculum/README.md`'s applicability notes, the
top-level README's hardware-truthfulness section) - don't leave stale
caveats about a problem that's already fixed.
