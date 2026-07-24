# RealDigital BlackBoard (Rev. D)

| | |
|---|---|
| FPGA | Zynq-7000 `xc7z007sclg400-1` (single-core Cortex-A9 + Artix-7 fabric, 23K logic cells, 60 DSP slices) |
| Vivado board_part | `realdigital.org:blackboard_d:part0:1.2` |
| PL fabric clock | 100 MHz oscillator, net `CLK100_IN`, pin `H16`, `LVCMOS33` |
| PS reference clock | 33.3333 MHz (DSC6111CI2-33.3333), separate from the PL oscillator above |
| USB-JTAG/UART | FTDI FT2232HQ |
| Peripherals | 4 PL pushbuttons, 12 slide switches (8 on Rev A/B, +4 on Rev C/D), 10 LEDs (LED0 + LED1-9) + 2 RGB LEDs, 4-digit 7-seg, 3 Pmod (JA/JB/JC, JA doubles as XADC header), DDR3 (ISSI IS46TR16256AL, 512MB), HDMI/DVI out, iNEMO IMU (I2C), PDM mic, PWM audio out, 16MB QSPI, ESP32 Wi-Fi/BT module, 4x servo headers, USB OTG |
| Reference material | Setup guide: https://www.realdigital.org/doc/30280f10e43c47ef6966d0f59a70bde9 · Programmer's reference (vendored): `docs/BlackBoard_ProgrammersReference.pdf` · Schematic (vendored): `docs/BlackBoard_revD_Schematic.pdf` |
| Board support repo | https://github.com/RealDigitalOrg/linux-blackboard (has real XDC + board_files, unlike the older `RealDigitalOrg/Blackboard` repo which only ships prebuilt Vitis platforms) |

## What's vendored here

- `xdc/BlackBoard-RevD-Master.xdc` - the **real, official constraints file**
  for Rev. D, copied verbatim from `linux-blackboard/hw/blackboard_revd.xdc`.
  This replaced an earlier hand-derived draft in this repo once the correct
  upstream source was found - every pin below is vendor-verified, not
  transcribed off a schematic image.
- `board_files/blackboard_d/1.2/` - the official Vivado board_files
  (`board.xml`, `part0_pins.xml`, `preset.xml`), same upstream repo.

## Reading the master XDC

A few things worth knowing before you copy lines out of
`xdc/BlackBoard-RevD-Master.xdc`:

- **Board revisions differ.** The file's own comments document exactly which
  GPIO indices exist on Rev A/B vs Rev C vs Rev D - Rev D adds 4 extra slide
  switches, 6 extra LEDs, a 3rd Pmod (JC), and 4 servo outputs that earlier
  revisions don't have. This repo assumes **Rev D** (confirmed hardware
  revision). If you have an earlier revision, don't blindly use the Rev-D-only
  lines.
- **Port names are `PS_GPIO_tri_io[N]`, not raw board silkscreen labels.**
  In RealDigital's reference design these physical pins are wired to a Zynq
  PS EMIO GPIO port (hence the name), but the *physical* `PACKAGE_PIN` +
  `IOSTANDARD` pair is a plain Artix-7 fabric pin like any other - nothing
  requires routing through the PS. For pure-PL modules (everything before
  `curriculum/13_zynq_ps_bringup`), rename the port to whatever your top
  module calls it (`sw[0]`, `led[0]`, `btn[0]`, ...) exactly like the Nexys4
  workflow. The GPIO index -> physical pin mapping (from the XDC comments):

  | Signal | GPIO indices | Notes |
  |---|---|---|
  | Pushbuttons BTN0-3 | 0-3 | |
  | Slide switches SW0-7 | 4-11 | all revisions |
  | Slide switches SW8-11 | 36-39 | Rev C/D only |
  | Pmod JA (also XADC) | 12-19 | |
  | Pmod JB | 20-27 | |
  | Pmod JC | 28-35 | Rev C/D only |
  | LED0 | dedicated `ONE_HZ` port, pin `N20` | not a GPIO index |
  | LED1-3 | 42-44 | |
  | LED4-9 | 45-50 | Rev D only |
  | Servo 0-3 | 51-54 | Rev D only |
  | RGB LED 10 (R/G/B) | 55-57 | Rev D only |
  | RGB LED 11 (R/G/B) | 58-60 | Rev D only |

- **HDMI, 7-segment, IMU I2C** all have their own plain port names
  (`hdmi_out_tmds_*`, `N_SEGMENTS[N]`/`N_ANODES[N]`, `iic_gyro_*`) - no GPIO
  indirection.

## Refreshing vendored files

```sh
git clone --depth 1 https://github.com/RealDigitalOrg/linux-blackboard.git
```

then copy `hw/blackboard_revd.xdc` and `board_files/rev_d/` back in - see
`scripts/fetch_vendor_files.sh`.
