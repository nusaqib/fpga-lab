# 07 - Block RAM and FIFOs

**Goal:** on-chip memory done right. How to write RTL that Vivado maps
onto real block-RAM primitives (and why the read register is
non-negotiable), then the canonical structure built on top of memory - the
synchronous FIFO with the extra-pointer-bit trick - verified against the
abstract data type it implements.

## The concept modules (`hdl/`)

| Module | What it teaches |
|---|---|
| `bram_sdp.v` | inferring a simple-dual-port BRAM: registered read, read-first collision semantics, `ram_style` |
| `fifo_sync.v` | pointer-based synchronous FIFO: the extra pointer bit, valid-gated push/pop, single-clock-only warning |
| `fifo_echo_top.v` | hardware demo: enqueue switch patterns fast, watch them replay in order slowly |
| `tick_gen.v`, `debounce.v`, `edge_detect.v`, `sync2.v` | the module 04 input stack, reused |

### Inferring BRAM (bram_sdp.v)

Three things make the synthesizer's pattern-matcher say "block RAM":

1. **A registered read** (`if (re) rdata <= mem[raddr];`). Real BRAM
   primitives have no combinational read path - ask for
   `assign rdata = mem[raddr];` and you get LUTRAM instead, silently,
   because that's the only primitive that CAN do it. The 1-cycle read
   latency is a property of the silicon, and every design built on BRAM
   is shaped around it.
2. **Cross-port collision semantics you didn't choose**: read the address
   being written this cycle and you get the OLD data. The bench pins this
   down with a directed test rather than leaving it folklore.
3. `(* ram_style = "block" *)` - not required at this depth (1024x8 would
   infer BRAM by size anyway), but stating intent means a future change
   that breaks inferability fails loudly at synthesis. After building,
   check the synthesis log confirms a `RAMB18`/`RAMB36` got used
   (`grep -i ramb _out/<board>/vivado/*.runs/synth_1/runme.log`).

### The synchronous FIFO (fifo_sync.v)

The design worth memorizing: read/write pointers **one bit wider** than
the RAM address. All bits equal = empty; address bits equal but top bit
different = the writer has lapped the reader once = full. Without that
bit, `rd == wr` is ambiguous between empty and full, and every workaround
is uglier. Bonus: `count = wptr - rptr` just works, including at full.

Interface protocol: pushes and pops are *requests*, gated internally
(`wr_en && !full`, `rd_en && !empty`) - asserting them at the wrong time
is ignored, never corrupting. One subtle convention the bench encodes: a
simultaneous push+pop **while full** accepts the pop but still rejects the
push, because `full` reflects the pointers *now*, not what the pop is
about to free. (Same as Xilinx's FIFO cores - WR while FULL is an
overflow, simultaneous RD or not. This exact case was a bench-model bug
during development; the fix is preserved in a comment.)

**The single-clock warning:** everything above assumes both sides see the
pointers instantly - true only within one clock domain. The FIFO that
survives crossing two clocks (Gray-coded pointers through synchronizers)
is module 08's capstone, and the reason FIFOs and CDC are taught
back-to-back.

## Simulation

```sh
make sim-all    # tb_bram_sdp, tb_fifo_sync
```

New machinery: `tb_fifo_sync` uses a **SystemVerilog queue** (`byte
model[$]`) as the golden model - the natural reference, since a queue is
literally the ADT a FIFO implements. Directed fill-to-full/drain-to-empty
with boundary checks, then a 2000-cycle random soak where pushes and pops
freely collide with the flags.

## Hardware demo (`fifo_echo_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

Set the switches, press the button - that pattern is enqueued. Do it
several times quickly with different patterns. The LEDs pop one entry
every 2 seconds: your patterns come back **in order**, at the consumer's
pace, long after your fingers left the switches. Producer and consumer
decoupled by a queue - the entire reason FIFOs exist, visible at 0.5Hz.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
