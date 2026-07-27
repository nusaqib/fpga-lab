# 28 - Verification basics: when directed tests stop being enough

**Goal:** a step up from the ad hoc benches every module so far has
used - by demonstrating, on a planted bug, exactly where they fail.
This module is simulation-only on purpose: verification methodology has
no pins.

## The setup

Two FIFOs, one bug:

- `hdl/fifo8.v` - module 07's synchronous FIFO, flags derived
  combinationally from the pointers. Correct.
- `hdl/fifo8_buggy.v` - identical, except `full` is a REGISTERED flag
  computed from the *current* count ("one flop for timing!"). It
  asserts one cycle late; a back-to-back push at the full boundary is
  accepted, overwrites the oldest entry, and - the nasty part - at
  count 9 the `count==8` compare goes false and `full` *deasserts*.
  A real-world bug class: flags must derive from next-state.

## The three benches tell one story

**`tb_fifo_directed.v`** - a careful, polite, self-checking directed
bench (fill to full, drain, interleave - what every earlier module
did). It passes on the correct FIFO **and on the buggy one**, and its
PASS criterion encodes that: if directed testing ever catches the
planted bug, the bench fails, because the premise would be wrong.
Directed tests verify the scenarios their author imagined; this
author - like most - pushes, waits a cycle, and checks.

**`tb_fifo_random.sv`** - constrained-random with a scoreboard:
20,000 cycles of *bursty* pushes (bursts matter - uniform random
single-cycle pushes rarely hit back-to-back-at-full either) against an
SV queue as the golden model. Catches the corruption **at cycle 43**.
Verdict requires all three: correct FIFO clean, buggy FIFO caught,
every coverage bin hit. Also on board:

- **SVA concurrent assertions** on structural invariants (`count <= 8`,
  never full&&empty, empty==(count==0)) - properties that must hold
  under any stimulus, checked continuously.
- **Functional coverage, demystified**: hand-rolled counters - the
  occupancy histogram 0..8, simultaneous push+pop, push-at-full,
  pop-at-empty, back-to-back-push-at-boundary. Coverage is just "which
  interesting situations actually happened"; counting them yourself
  once removes the covergroup mystery. (Bonus lesson caught during
  authoring: an uninitialized `integer` histogram counts x+1=x forever
  AND defeats the ==0 hole check - a coverage bug hiding a coverage
  hole.)

## cocotb

**Blocked on tooling** (honestly, like Tier 6): cocotb needs pip and a
supported simulator (Icarus/Verilator - xsim isn't one); this machine
currently has neither pip nor sudo. When that changes:
`pip install cocotb`, `apt install iverilog`, and the natural exercise
is porting `tb_fifo_random`'s scoreboard to a Python coroutine bench.
The concepts here (random stimulus, golden model, coverage-driven
verdicts) transfer verbatim - cocotb changes the language, not the
methodology.

## Run

```sh
make sim-all
```

Expected: the directed bench prints its own punchline ("0 errors <- the
lesson"), the random bench prints the coverage table and where it first
caught the corruption.

## Board status

| Board | Status |
|---|---|
| all | n/a - simulation-only module by design |
