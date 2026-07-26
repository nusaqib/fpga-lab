# 04 - Clock dividers and debouncing

**Goal:** the two workhorse idioms every real FPGA design with human inputs
needs, and the first *classic blinky*. This module also completes the
button-input stack that modules 03 promised:

```
raw pin -> sync2 -> debounce -> edge_detect -> exactly one pulse per press
```

## The concept modules (`hdl/`)

| Module | What it teaches |
|---|---|
| `tick_gen.v` | one-cycle enable pulse every DIV clocks - "divide" a clock the right way |
| `debounce.v` | commit an input change only after it holds STABLE_COUNT cycles |
| `edge_detect.v` | one-cycle pulse per rising edge of a clean input |
| `sync2.v` | copied from module 03 (modules stay self-contained) |
| `blinky_counter_top.v` | 1Hz blinky + press counter, composing all of the above |

### "Clock divider" - the idiom versus the trap

`tick_gen` does NOT produce a slower clock signal; it produces a
*one-cycle-wide enable pulse* every DIV cycles, and downstream logic stays
on the one real clock:

```verilog
always @(posedge clk)
    if (blink_tick) blink_state <= ~blink_state;
```

The tempting alternative - toggling a `reg` and using it as a new clock
(`always @(posedge slow_clk)`) - works in simulation, then ages badly in
hardware: the derived clock travels over general routing instead of the
dedicated clock network, every divider adds a real clock domain to
analyze, and timing between domains gets messy. On FPGAs: **one clock, many
enables.** (When a genuinely different clock frequency is needed, an
MMCM/PLL primitive does it properly - that's Tier 4, `10_ip_integrator_intro`.)

Also worth noticing in `tick_gen`: `$clog2(DIV)` sizes the counter register
to exactly fit - a small but constantly-used Verilog idiom.

### Debouncing - why and how

Mechanical contacts bounce: one physical press produces dozens of
electrical edges over several milliseconds. Module 03's `capture_top` got
away without debouncing because a level-sensitive enable just re-captures
during the storm - but the moment anything *edge-triggered* sits behind a
button (a counter, an FSM transition), every bounce becomes an event.

`debounce.v` is the standard counter-based filter: synchronize first
(`sync2`), then require the new level to survive `STABLE_COUNT` consecutive
cycles (default 10ms at 100MHz) before committing it to the output.

**`sim/tb_button_pulse.v` is the module's centerpiece:** it feeds the same
deliberately-bouncy presses into a naive `sync2 -> edge_detect` path and
the full debounced path, side by side. The debounced path counts exactly 5
presses; the naive path overcounts - and the bench *asserts* the naive path
overcounts, because a bounce model tame enough for the naive path to pass
wouldn't be demonstrating anything.

## Simulation

```sh
make sim-all    # tb_blinky_counter_top, tb_button_pulse, tb_debounce, tb_tick_gen
```

New trick this module: every DUT parameter (`BLINK_DIV`, `STABLE_COUNT`)
is overridden to tiny values in the benches. Simulating the real
100-million-cycle second would burn minutes proving nothing - sizing
parameters down for simulation (while hardware keeps the real values) is
standard practice.

## Hardware demo (`blinky_counter_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

- `led[3]` blinks at 1Hz - the classic proof-of-life.
- `led[2:0]` counts button presses (Nexys4: BTNC; BlackBoard: BTN0) -
  press 5 times, read 5 (then it wraps at 8, it's 3 bits).

If you want to *see* why the debouncer earns its place on real hardware:
in `blinky_counter_top.v`, rewire `u_edge.level_in` from `btn_clean` to the
raw synchronized button and rebuild - single presses will jump the count
by random amounts. (BlackBoard fun fact: its LED0 is exactly the "1Hz
blink" LED in the factory reference design - same job, now our RTL.)

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
