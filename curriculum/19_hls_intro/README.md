# 19 - HLS intro

**Goal:** Tier 7 opens. The same block this repo already built by hand -
module 12's AXI-Stream x3 scaler, skid buffer and all - written as ~15
lines of C++ and pushed through Vitis HLS: C simulation, C synthesis to
RTL, and C/RTL co-simulation. The point isn't that HLS is better or
worse; it's knowing *exactly* what the pragmas bought and what they cost,
with the hand-written version sitting right there for comparison.

**Toolchain note (2026.1):** like XSCT, the classic `vitis_hls` binary is
gone. The unified flow is `v++ -c --mode hls` (C synthesis) and
`vitis-run --mode hls --csim/--cosim` (simulations), driven by a
generated config file. `common/mk/hls.mk` wraps all of it; the config is
generated per-build so the part number follows `BOARD`.

## The kernel (`hls/axis_scaler_hls.cpp`)

`hls::stream<ap_axiu<32,0,0,0>>` in and out, `read() -> *3 -> write()`.
Three pragmas do all the work:

| Pragma | What it does |
|---|---|
| `INTERFACE mode=axis` | maps the streams to real AXIS ports (TDATA/TLAST/TVALID/TREADY) |
| `INTERFACE mode=ap_ctrl_none` | no start/done handshake - free-running, like RTL |
| `PIPELINE II=1` | one beat per cycle; the tool builds whatever handshake registering that needs |

## The comparison (vs `curriculum/12_axi_stream/hdl/axis_scaler.v`)

| | Hand-written (module 12) | HLS (this module) |
|---|---|---|
| Source | ~60 lines of Verilog + a hand-derived registered-ready equation | ~15 lines of C++ + 3 pragmas |
| Design effort | a skid buffer with occupancy accounting; first draft dropped a beat under backpressure until the bench caught it | `PIPELINE II=1` |
| Result (csynth est., xc7a100t) | - | II=1, latency 1 cycle, ~74 LUT / 3 FF, est. Fmax 220 MHz |
| Verification | SV bench with hostile random TREADY | csim (function only - **no TREADY concept in C**), then cosim: same C bench re-run against the generated Verilog in xsim, where real handshakes exist |
| Debuggability | every register has a name you chose | generated RTL (open `_out/hls/<board>/axis_scaler_hls/hls/impl/verilog/axis_scaler_hls.v` and judge for yourself) |

Two honest observations worth carrying forward: csim is fast and
convenient but verifies the *function*, not the *protocol* - cosim is the
one that would catch a handshake bug, which is why `make hls-cosim` is
part of this module's definition of done. And the HLS output here is
genuinely good (this is a trivially pipelineable kernel - the best case);
Tier 7's later modules probe where that stops being automatic.

## Build

```sh
make hls-csim     # C bench vs C++ (fast)
make hls-synth    # C -> RTL; reports under _out/hls/<board>/.../syn/report/
make hls-cosim    # same C bench vs the GENERATED VERILOG in xsim
make hls-report   # csynth summary to stdout
```

No `hdl/`, no `constraints/`: dropping the generated IP into a real
block design next to the Tier 4/5 infrastructure is module 21's job.

## Board status

| Board | Status |
|---|---|
| nexys4 (default part target) | csim + csynth + cosim all pass |
| blackboard / rfsoc4x2 | same flow, `BOARD=` switches the part; hardware integration deferred to module 21 |
