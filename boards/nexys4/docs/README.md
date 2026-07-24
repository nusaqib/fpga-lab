# Digilent Nexys4

| | |
|---|---|
| FPGA | `xc7a100tcsg324-1` (Artix-7, CSG324, speed grade 1) |
| Vivado board_part | `digilentinc.com:nexys4:part0:1.1` |
| Clock | 100 MHz, sch. name `CLK100MHZ`, pin `E3` |
| Reference | https://digilent.com/reference/programmable-logic/nexys-4/start |

**Important:** this is the original **Nexys4** (no DDR), not the later
**Nexys4 DDR**. The two boards look alike and share a product family name but
have different pinouts and part markings - do not swap constraint files
between them. If you actually hold a Nexys4 DDR, get its master XDC from
https://github.com/Digilent/digilent-xdc (`Nexys-4-DDR-Master.xdc`) and add a
sibling `boards/nexys4_ddr/` following this same layout.

## What's vendored here

- `xdc/Nexys4-Master.xdc` - the full, official master constraints file from
  Digilent's [`digilent-xdc`](https://github.com/Digilent/digilent-xdc) repo
  (MIT licensed, see `xdc/LICENSE-digilent-xdc.txt`). Every pin on the board
  is listed but commented out; curriculum modules copy in only the lines they
  need.
- `board_files/nexys4/B.1/` - the official Vivado "board files" (`board.xml`,
  `part0_pins.xml`, `preset.xml`) from Digilent's
  [`vivado-boards`](https://github.com/Digilent/vivado-boards) repo. Installing
  these lets Vivado's IP integrator auto-configure IP (e.g. board presets)
  from the `digilentinc.com:nexys4:part0:1.1` board part. Not required for the
  Makefile-driven flow used by this repo (which passes `-part` directly), but
  useful once you start using IP integrator / block designs.

To make the board_files visible inside the Vivado GUI (optional):

```tcl
set_param board.repoPaths [list "/home/nusaqib/gitsrc/embed/fpga-lab/boards"]
```

(add to your `Vivado_init.tcl`, see `docs/tool_setup.md` at the repo root).

## Refreshing vendored files

Re-run:

```sh
git clone --depth 1 https://github.com/Digilent/digilent-xdc.git
git clone --depth 1 https://github.com/Digilent/vivado-boards.git
```

and copy the relevant files back in - see `scripts/fetch_vendor_files.sh`.
