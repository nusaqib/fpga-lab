# 08 - Clock domain crossing

**Goal:** the discipline for moving information between unrelated clocks -
the single biggest source of "works in sim, fails randomly on hardware"
bugs in real designs. Three tools in escalating capability, each proven
under two genuinely unrelated simulation clocks (7ns and 11.3ns periods):

| Tool | Carries | Cost | Use when |
|---|---|---|---|
| `sync2` (module 03) | a level (1 bit) | 2 flops | slow-changing status/flags |
| `pulse_sync.v` | an event | toggle + sync2 + edge | occasional single-cycle events |
| `handshake_sync.v` | a word, occasionally | ~4-6 cycles per word | low-rate config/status values |
| `fifo_async.v` | a stream, fast | BRAM + Gray pointers | real data - the capstone |

## The rules the modules embody

1. **A level crosses safely through two flops; nothing else does.**
   `sync2` works because its input holds still long enough to be sampled
   again. A single-cycle pulse from a fast domain can fall entirely
   between slow-domain edges - `pulse_sync` fixes that by converting the
   event to a level *change* (a toggle), crossing the level, and
   re-deriving the pulse with an any-edge detector. Its inherited limit:
   events closer together than ~3 destination cycles merge.

2. **Never pass a multi-bit value through per-bit synchronizers.** Each
   bit resolves independently; 0111->1000 can be seen as anything for a
   cycle. `handshake_sync` obeys this by freezing the word in the source
   domain and crossing only two single-bit signals (req/ack, 4-phase);
   the destination samples data that provably hasn't moved since before
   req rose.

3. **The one legal-looking exception proves the rule.** `fifo_async`
   *does* run its pointers through per-bit `sync2`s - legal only because
   they're **Gray-coded** (successive values differ in exactly one bit,
   so a mid-flight sample returns either the old or new value, never a
   phantom). That, plus flags that err conservative (each side sees the
   other's pointer 2 flops late: `full` pessimistic, `empty` stale, both
   safe directions), is the entire async FIFO trick. Same skeleton as
   module 07's `fifo_sync` otherwise - extra pointer bit and all.

## Simulation

```sh
make sim-all    # tb_fifo_async, tb_handshake_sync, tb_pulse_sync
```

All three benches run two free-running unrelated clocks and test both
directions (fast->slow and slow->fast). `tb_fifo_async` pushes 2000 words
each way against SV queue models and *requires* backpressure to have been
exercised (the fast-writer instance must hit `full` at least once, or the
test declares itself too tame and fails).

**A bug this module caught in earlier modules' code:** `sync2`'s two flops
had no power-up initializers, so in simulation its output starts `x` - and
`handshake_sync`'s `src_busy` (which depends on the synced ack) started
`x`, silently swallowing the first word: `if (src_valid && !src_busy)`
with `x` takes the no-branch, and the bench's first-word-lost failure led
straight to it. Fixed in every module's copy of `sync2` (03/04/06/07/08) -
module 05's initializer lesson, applied one level deeper.

## Hardware demo (`cdc_demo_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

Module 07's FIFO echo with the producer moved into a genuinely
asynchronous clock domain: **your thumb**. The debounced button is the
write clock itself - each press is one wclk edge pushing the switch
pattern; the 100MHz side pops one entry per second onto the LEDs. Punch
in patterns, watch them replay in order. (Clocking fabric flops from a
debounced button is fine at human speeds but expect Vivado warnings about
the fabric-routed clock; constraining internal clocks properly is module
09's business. The constraints exempt the Gray-pointer crossings
explicitly with `set_false_path`.)

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
