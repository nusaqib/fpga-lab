# 12 - AXI-Stream

**Goal:** streaming done right. AXI-Stream is AXI with the addresses
deleted - TDATA + the same valid/ready handshake + TLAST packet framing -
and it's how sample data moves everywhere from here on (DMA in Tier 5,
HLS in Tier 7, RF samples in Tier 8). The module's centerpiece is the
**skid buffer**, the one structure every serious stream design contains.

## The pipeline (`hdl/`, wired up in `bd/axis_pipe_sys.tcl`)

```
axis_counter_src --> axis_scaler (x3, skid) --> axis_capture
 (one packet of 16                                 ^ AXI4-Lite status
  beats per button press)      jtag_axi ----------/      (JTAG-readable)
```

| Block | What it teaches |
|---|---|
| `axis_counter_src.v` | an AXIS master done honestly: stalls hold TDATA/TVALID steady, TLAST placed on the final beat |
| `axis_scaler.v` | the skid buffer (below) |
| `axis_capture.v` | AXIS sink + AXI4-Lite observation window (module 11's register style, reused) |

### The skid buffer - why and how

For timing you want your block's outputs AND its upstream-facing
`tready` to come from registers (module 09 taught why long combinational
paths hurt). But a registered `tready` is one cycle stale: when
downstream stalls, upstream finds out a cycle late - and by then it has
already launched one more beat at you. The skid buffer is a one-beat
side register that catches exactly that in-flight beat. Rules:

- accept whenever your (registered) `s_tready` was high and valid arrived,
- `s_tready` goes low only when *both* the output register and the skid
  register are occupied,
- when downstream frees up, drain the skid **first** (order preserved),
- the drain-and-refill-same-cycle case must move the skid contents out
  and the incoming beat in simultaneously - forgetting it drops a beat
  (the first draft of this very module had that bug; the bench below is
  what catches it).

`tb_axis_pipeline` runs 30 packets through the pipeline with a hostile
downstream (TREADY random every cycle) against a sequence model, checks
every beat's value and TLAST position, and separately enforces the
AXI-Stream stability rule (a stalled beat must not change). If the skid
logic dropped or duplicated a single beat, the whole sequence shifts and
the bench fails loudly.

### Where's the DMA?

The syllabus originally said "AXI DMA" here, but the real AXI DMA IP
moves data between streams and *memory* - and the only real memory on
these boards hangs off the Zynq PS, which arrives in Tier 5. Rather than
fake it, this module builds the streaming discipline (and the
JTAG-observable pipeline); `axi_dma` itself joins in module 14/15 where
it has actual DDR to talk to. The capture block's AXI4-Lite window is
the manual, CPU-less stand-in for "a memory-mapped sink".

## Hardware (`axis_demo_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
```

Each button press fires one 16-beat packet through the pipeline; the
LEDs show the capture block's beat counter jumping by 16. Then observe
over JTAG (Hardware Manager Tcl console, like module 11):

```tcl
create_hw_axi_txn rd_last [get_hw_axis hw_axi_1] -type read -address 00000000
create_hw_axi_txn rd_beats [get_hw_axis hw_axi_1] -type read -address 00000004
create_hw_axi_txn rd_pkts [get_hw_axis hw_axi_1] -type read -address 00000008
run_hw_axi rd_beats
run_hw_axi rd_pkts
run_hw_axi rd_last   ;# last beat = (16n-1)*3 - the scaler at work
```

## Simulation

```sh
make sim-all    # tb_axis_pipeline
```

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
