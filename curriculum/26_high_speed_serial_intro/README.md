# 26 - High-speed serial intro: the GTY transceivers (IBERT on QSFP28)

**Goal:** meet the fastest pins on any of these boards - the RFSoC4x2's
four GTY transceivers behind the 100G QSFP28 cage - using IBERT, the
tool made for exactly this: pattern generators, error checkers and
eye-scan engines dropped into the quad, driven interactively from the
Hardware Manager. **No QSFP module is needed** for the core exercise:
the transceivers can loop TX to RX internally.

## What a serial link bring-up actually involves (the concepts)

- **A quad, not a pin.** GTYs come four channels to a quad with shared
  PLLs (QPLL0/1) and dedicated refclk inputs. The QSFP28 sits on
  **quad 128**; its reference is **156.25 MHz on AA33/AA34**
  (`GTY_128_REF_CLK_QSFP` - RealDigital reference manual Appendix A,
  independently confirmed by Vivado's own MGTREFCLK0_128 pin mapping).
  Line rate here: **10.3125 Gb/s** = the classic 10GbE pairing with a
  156.25 MHz refclk (x66 via QPLL0).
- **There is no clock wire.** At 10 Gb/s the receiver recovers the
  clock from the data's own transitions (CDR). That only works if data
  keeps transitioning - which is why real protocols scramble or encode
  (64b/66b adds 2 sync bits per 64 data bits; 8b/10b pays 25% for DC
  balance). IBERT sidesteps protocol and sends PRBS patterns -
  pseudo-random sequences the checker can regenerate and compare
  bit-for-bit, which is how BER is measured without any framing.
- **The eye.** Signal integrity at these rates is analog business:
  equalization (CTLE/DFE on RX, pre/post-cursor emphasis on TX) fights
  channel loss. The GTY has a built-in eye-scan engine: it sweeps
  sampling phase/offset and plots where the data is still recoverable -
  the "eye". Open eye = margin; closing eye = errors soon.
- **Refclk purity is everything.** Fabric clocks come from anywhere;
  serial refclks get dedicated pins, dedicated buffers (`IBUFDS_GTE4`)
  and jitter-obsessed clock chips (the Si5395 here). The only fabric
  logic in this whole design is one BUFG_GT so IBERT's control logic
  can share the refclk.

## Files

- `ip/ibert_qsfp.tcl` - the IBERT IP: quad 128, MGTREFCLK0_128 (default
  for this part - asserted, not assumed), 10.3125 Gb/s, sysclk from the
  refclk's fabric copy. Uses the build system's IP_TCL hook (module 10).
- `hdl/ibert_qsfp_top.v` - adapted from the IP's generated example
  design: refclk buffer, BUFG_GT, core. Also drives the QSFP sideband
  (RESETL=1, LPMODE=0) so a physical loopback plug works unmodified.
- `constraints/rfsoc4x2.xdc` - refclk LOC + `create_clock` + dbg_hub
  clock config. The 8 lane pins need nothing: the quad choice fixes them.

## Run it

```sh
make bitstream program
```

Then in Vivado: *Open Hardware Manager -> auto-detects the IBERT core*.
The Serial I/O Analyzer shows 4 links down (no module - expected).

1. Create links for the 4 lanes (TX n -> RX n).
2. Set **Loopback = Near-End PMA** on each link: TX loops to RX inside
   the transceiver, before the pins. Links come up, BER starts
   integrating at ~10^-12 per second of runtime.
3. Right-click a link -> **Create Scan**: the eye, measured by the
   silicon itself.
4. Flip loopback back to None and watch errors flood - that's CDR
   losing lock with no signal. (With a QSFP loopback plug: links stay
   up with loopback None, now through 30cm of real copper + connector.)

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | bitstream builds; bench run = Hardware Manager session (above) |
| nexys4 / blackboard | n/a - no gigabit transceivers on these parts |
