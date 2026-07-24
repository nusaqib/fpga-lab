# Toolchain setup

Vivado/Vitis 2026.1 is installed at `/opt/tools/2026.1`. Every Makefile in
this repo sources the vendor `settings64.sh` itself (see
`common/mk/common.mk`), so you generally don't need to source anything by
hand to run `make`. `env.sh` at the repo root is provided for interactive use
(launching the Vivado/Vitis GUI directly, or running `vivado`/`xsct` ad hoc):

```sh
source env.sh
vivado &
```

## Verifying the install

```sh
source env.sh
vivado -version
```

Expected: `vivado v2026.1 (64-bit)`.

## Making vendored board_files visible in the Vivado GUI (optional)

The Makefile-driven flow in this repo never needs Vivado's board_part catalog
- it passes `-part <FPGA_PART>` directly to `create_project` and, when a
board_part id is known, sets it as a property afterwards. But if you want
Vivado's IP integrator to offer board presets (e.g. Zynq PS auto-config) when
you open a project or the generated `.xpr` in the GUI, add this to your
`Vivado_init.tcl`:

```tcl
set_param board.repoPaths [list "/home/nusaqib/gitsrc/embed/fpga-lab/boards"]
```

`Vivado_init.tcl` location:
- Linux: `~/.Xilinx/Vivado/Vivado_init.tcl`

## Licensing

Vivado/Vitis license configuration is outside the scope of this repo - if
`vivado -version` complains about licensing, resolve that with your normal
Xilinx/AMD license setup before continuing.
