# 21 - HLS streaming and dataflow

**Goal:** Tier 7's capstone. Two streaming stages - module 20's FIR and a
decimate-by-2 - live inside ONE HLS function, connected by an internal
`hls::stream` and scheduled with `#pragma HLS DATAFLOW`. Then the
generated kernel is packaged as real Vivado IP and dropped into module
12's stream infrastructure on hardware, completing the loop this tier
opened: C++ in, JTAG-observable silicon out.

## DATAFLOW vs PIPELINE - the distinction that matters

`PIPELINE II=1` is *instruction-level* parallelism inside one process:
overlap the iterations of a loop/function body. `DATAFLOW` is
*task-level* parallelism between processes: `fir_stage` and
`decim_stage` become concurrently-running blocks with a FIFO between
them - exactly the src -> scaler -> capture architecture module 12 built
from three hand-written RTL modules, except the tool builds the FIFOs
and handshakes from the code structure. The two pragmas compose: each
stage is II=1 inside, the pair overlaps outside.

Two tool-taught rules encoded in the source:

- **`ap_axiu` is for ports only** (HLS 214-208): between dataflow stages
  you define your own struct (`mid_t {data, last}`) and carry just what
  matters. The sideband-heavy AXIS type is an interface contract, not a
  general datatype.
- **Decimation must not swallow TLAST**: the keep/drop toggle re-frames
  packets 16 -> 8 beats, with the boundary beat always kept and the phase
  reset at end-of-packet so packets stay aligned.

Numbers: II=1 per stage, est. Fmax 174 MHz on the xc7a100t; cosim (the
handshake-accurate check) passes.

## The integration (`make hls-package` -> BD)

`hls.mk` gained `HLS_PKG=ip_catalog` + `make hls-package`: the kernel is
packaged as a Vivado IP (component.xml et al.) under
`_out/hls/<board>/<top>/hls/impl/ip`, the Makefile exports that path,
and `bd/hls_pipe_sys.tcl` adds it to `ip_repo_paths` and instantiates
`xilinx.com:hls:fir_decim_hls:1.0` between module 12's counter source
(width-switched to 16) and capture block (this module's copy is 16-bit
with sign-extension - Q1.15 samples now, not raw counters). The
bitstream rule order-only-depends on `hls-package`, so a fresh checkout
builds end to end with one command.

```sh
make BOARD=nexys4 bitstream      # packages the IP first, automatically
make BOARD=nexys4 program
```

On hardware, same drill as module 12 - each button press fires one
16-beat packet, but the LEDs jump by **8** per press (the decimator at
work). Over JTAG (Hardware Manager Tcl console): BEATS counts 8/packet,
PKTS 1/press, LAST_DATA holds the FIR output of the final sample,
sign-extended.

## Simulation

```sh
make hls-csim     # C model of both stages + TLAST re-framing
make hls-cosim    # same bench vs generated RTL - the handshake truth
```

## Board status

| Board | Status |
|---|---|
| nexys4 | ready (bitstream builds with packaged HLS IP) |
| blackboard | ready (same) |
| rfsoc4x2 | deferred: no free-running PL clock for the JTAG-observed variant; HLS kernels join the PS-based stream infrastructure in Tier 8 |
