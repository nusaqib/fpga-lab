# RF clock chip register dumps (vendored, do not hand-edit)

`LMK04828_245.76.txt` and `LMX2594_491.52.txt` were copied **verbatim** from
the official Xilinx RFSoC-PYNQ board repo:

    https://github.com/Xilinx/RFSoC-PYNQ
    boards/RFSoC4x2/petalinux_bsp/meta-user/recipes-apps/xrfclk-tics/files/

These are TI TICS Pro register exports - the exact values the PYNQ image's
`xrfclk` package writes into the board's clock chips at boot
(`xrfclk.set_ref_clks(lmk_freq=245.76, lmx_freq=491.52)`):

- **LMK04828** (SPI0 CS0): system clock generator/distributor - 245.76 MHz
  reference distribution, 136 writes of 24 bits each, in file order.
- **LMX2594 x2** (SPI0 CS1 = DAC tiles, CS2 = ADC tiles): RF synths making
  the 491.52 MHz sample refclk for the RFDC tile PLLs. 113 registers listed
  R112 down to R0; programming protocol (from PYNQ's `xrfclk.py`): write
  0x020000 (RESET=1), 0x000000 (RESET=0), all 113 values in file order,
  then the R0 line once more so FCAL runs from a stable state.

All three chips sit on PS **SPI0** (per the same repo's `system-user.dtsi`):
LMK04828 at CS0, LMX2594 (DAC) at CS1, LMX2594 (ADC) at CS2, mode 0,
3-byte MSB-first transfers, conservatively clocked (DT says 500 kHz max;
the chips themselves tolerate several MHz).

`scripts/tics_to_header.py` converts these files into the C header used by
bare-metal modules (see `curriculum/22_rf_dc_intro/src/rfclk_regs.h`).
Refresh via `scripts/fetch_vendor_files.sh`.
