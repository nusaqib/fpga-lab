# RealDigital RFSoC4x2

| | |
|---|---|
| FPGA | Zynq UltraScale+ RFSoC `xczu48dr-ffvg1517-2-e` |
| Vivado board_part | `realdigital.org:rfsoc4x2:part0:1.0` |
| RF | 4x 14-bit ADC (up to 5 GSPS), 2x 14-bit DAC (up to 9.85 GSPS), SMA |
| DDR4 | 4 GB PS-side + 4 GB PL-side (8 GB total), 4x Micron MT40A512M16JY-083E each |
| Clocking | Skyworks Si5395B (PS/fabric), TI LMK04828 + 2x LMX2594 (RF sample clocks) |
| USB-JTAG/UART | FTDI FT2232H |
| Other | 2x USB3 host, 1x USB3 device, GigE (TI DP83867), 100G QSFP28, 30-pin Pmod+, SYZYGY, Mini DisplayPort, 16x2 OLED, microSD boot |
| Reference manual | RealDigital RFSoC 4x2 Reference Manual Rev A3: https://www.realdigital.org/downloads/15456c97a4fe5a1ee66208c5aa3894bb.pdf (also mirrored at http://www.rfsoc-pynq.io/rfsoc_4x2_overview.html) |
| Board support repo | https://github.com/RealDigitalOrg/RFSoC4x2-BSP |

## What's vendored here

- `xdc/*.xdc` - the official per-peripheral constraint files copied verbatim
  from `RFSoC4x2-BSP/hw/constraints/` (LEDs/buttons/switches, PMOD, SYZYGY,
  1PPS, PL DDR4, QSFP). These are real, verified pin/IOSTANDARD constraints,
  not hand-transcribed - use them directly.
- `board_files/rfsoc4x2/1.0/` - the official Vivado board_files (`board.xml`,
  `part0_pins.xml`, `preset.xml`) from the same repo, enabling Zynq PS preset
  auto-configuration in IP integrator later.
- `rfclk/` - the RF clock chips' (LMK04828 + 2x LMX2594) TICS register
  dumps, vendored verbatim from the official Xilinx/RFSoC-PYNQ repo - the
  exact values the PYNQ image programs at boot, used by
  `curriculum/22_rf_dc_intro`'s bare-metal clock bring-up. See
  `rfclk/UPSTREAM-README.md` for the SPI topology and per-chip protocol.

## Pins verified beyond the XDCs (from the reference manual, Appendix A)

- QSFP28: **GTY quad 128**, refclk `GTY_128_REF_CLK_QSFP` on **AA33/AA34**
  at 156.25 MHz (independently confirmed by Vivado's MGTREFCLK0_128 pin
  mapping) - used by `curriculum/26_high_speed_serial_intro`.
- RF tile mapping (via the PYNQ base overlay): DAC_A = DAC tile 230 blk 0
  (`vout20`), ADC_A = ADC tile 226 (`vin2_23`) - the tile-2 pair used by
  Tier 8.

## Pmod+ voltage - UNVERIFIED, treat as a hazard

The Pmod+ signals sit on an **LVCMOS18** FPGA bank (per the vendored
`4x2_PMOD.xdc`) while the connector's Vdd pins are **3.3V** (per the
reference manual), and the manual does not state whether the signal pins
are level-shifted. Until the schematic answers, do NOT wire this Pmod to a
3.3V board's Pmod (this is why `curriculum/29_multiboard_project` has no
RFSoC4x2 variant).

## Clocking gotcha for early (PL-only) modules

Unlike Nexys4, there is no simple always-on LVCMOS oscillator pin wired
straight into the PL fabric. The reference design's `pl_clk0` is generated
*by* the Zynq PS (`zynq_ultra_ps_e_0/pl_clk0`), which itself only starts once
the PS has booted/configured clocking - not available in a PL-only bitstream
with no PS block design. RF sample clocks depend on the LMK04828/LMX2594
synth chips being programmed over SPI, which is even further out.

**Implication for the curriculum:** modules before Zynq PS bring-up
(`curriculum/13_zynq_ps_bringup`) that target this board use a debounced
pushbutton edge as their "clock" (a T flip-flop toggled by `PB_0`, etc.)
instead of a free-running oscillator. See `curriculum/00_first_bitstream/`.
From module 13 on, `pl_clk0` from the configured PS is the fabric clock;
the RF sample clocks additionally need the LMK/LMX chain programmed over
PS SPI0 (see `rfclk/` above and module 22).

## Refreshing vendored files

```sh
git clone --depth 1 https://github.com/RealDigitalOrg/RFSoC4x2-BSP.git
```

then copy `hw/constraints/*.xdc` and `board_files/rfsoc4x2/` back in - see
`scripts/fetch_vendor_files.sh`.
