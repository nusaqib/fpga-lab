# Toolchain setup

Vivado/Vitis 2026.1 is installed at `/opt/tools/2026.1`. Every Makefile in
this repo sources the vendor `settings64.sh` itself (see
`common/mk/common.mk`), so you generally don't need to source anything by
hand to run `make`. `env.sh` at the repo root is provided for interactive use
(launching the Vivado/Vitis GUI directly, or running `vivado` ad hoc):

```sh
source env.sh
vivado &
```

## 2026.1 toolchain realities (load-bearing)

Two entry points that older documentation assumes are **gone in 2026.1**:

- **XSCT is disabled.** Bare-metal software builds go through the Vitis
  Python interface instead: `vitis -s <script.py>`. This repo's wrapper is
  `common/tcl/build_app.py`, driven by `make elf` (`common/mk/vitis.mk`).
- **There is no `vitis_hls` binary.** HLS is the unified flow:
  `v++ -c --mode hls` plus `vitis-run --mode hls` for csim/cosim/package.
  This repo's wrapper is `common/mk/hls.mk` (`make hls-*`).

Still present and used here: `sdtgen` (XSA -> System Device Tree, the input
to the Linux flow below) and `xsdb` (JTAG debug/ELF loading).

## Verifying the install

```sh
source env.sh
vivado -version
```

Expected: `vivado v2026.1 (64-bit)`.

## Embedded Linux: AMD EDF (Yocto), not PetaLinux

Tier 6 uses the **AMD Embedded Development Framework (EDF)** - the official
successor to PetaLinux (which is on a path to end-of-life; its final release
ships alongside EDF 26.11). EDF is plain upstream Yocto plus AMD layers and
tools; there is **no installer, no license, and no AMD account needed** -
everything comes from GitHub.

One-time setup (already done on this machine; recorded for reproducibility):

```sh
# host packages Yocto's sanity check requires (the only sudo step):
sudo apt install chrpath diffstat gawk lz4 curl mtools

# the repo tool + the EDF 2026.1 workspace:
mkdir -p ~/bin && curl -s https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo && chmod a+x ~/bin/repo
mkdir -p ~/yocto/edf && cd ~/yocto/edf
~/bin/repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2026.1 -m default-edf.xml
~/bin/repo sync
```

Day-to-day use:

```sh
cd ~/yocto/edf
source edf-init-build-env build      # BitBake environment, BUILDDIR=build/
```

The workspace lives OUTSIDE this repo (at `~/yocto/edf`) deliberately: a
Yocto build tree runs to 50+ GB and is shared between boards/modules via
`downloads/` and `sstate-cache/` - it does not fit the per-module `_out/`
convention. Module Makefiles reference it; see
`curriculum/16_edf_linux_bringup/`.

The custom-hardware entry point is `gen-machineconf` (from `meta-xilinx`),
which turns a System Device Tree - produced from any of our XSAs by Vitis's
`sdtgen` - into a Yocto MACHINE definition. Note: gen-machine-conf's older
`parse-xsa` mode is deprecated *and* depends on XSCT, so this repo only uses
the `sdtgen` -> `parse-sdt` path.

Two one-time customizations this repo makes to the workspace:

- `bitbake-layers add-layer <repo>/linux/meta-fpgalab` - the repo's own
  layer (module 17+): device-tree tweaks, app recipes, `fpgalab-image`.
- in `build/conf/local.conf`: `IMAGE_FSTYPES:append = " wic"` and
  `WKS_FILE = "edf-disk-single-rootfs.wks"` - EDF ships no flashable SD
  image by default; this emits one in the official EDF layout (p1 vfat
  boot, p2 storage, p3 ext4 root - the layout its `boot.scr` expects).
  See `curriculum/16_edf_linux_bringup/README.md` for the boot flow.

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
Xilinx/AMD license setup before continuing. (Practical note from experience:
on this machine failures have always been the node-locked license's HOSTID
not matching the actual Ethernet MAC - fixable in the AMD licensing portal,
never in this repo.) The EDF/Yocto flow needs no license at all.
