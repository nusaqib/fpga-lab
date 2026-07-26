# 06 - Finite state machines

**Goal:** the design pattern that carries every controller you will ever
write: explicit states, a registered state variable, combinational
next-state logic. Moore vs Mealy made concrete with twin sequence
detectors whose one-cycle output difference is *asserted* in the bench,
then a real project - a pedestrian-crossing traffic light.

## The concept modules (`hdl/`)

| Module | What it teaches |
|---|---|
| `sequence_detector_moore.v` | Moore FSM for serial "1011" (overlapping); output is a pure function of state |
| `sequence_detector_mealy.v` | same job as a Mealy FSM; one fewer state, output fires one cycle earlier |
| `traffic_light.v` | the real project: timed states, latched request, min-green guarantee |
| `traffic_top.v` | hardware demo at human speed (1 tick/second) |
| `tick_gen.v`, `debounce.v`, `edge_detect.v`, `sync2.v` | the module 04 input stack, reused |

### Moore vs Mealy - the actual tradeoff

Same pattern, same input stream, both correct - the difference is *when*
and *how clean*:

|  | Moore | Mealy |
|---|---|---|
| Output depends on | state only | state **and** input |
| "1011" detected | one cycle **after** the last bit | **same cycle** as the last bit |
| Output cleanliness | registered-clean, glitch-free | combinational on `din` - can glitch, eats setup margin downstream |
| States needed | 5 | 4 |

`tb_sequence_detectors.v` runs both machines against a sliding-window
golden model on the same stream (a directed overlapping prefix
"1011011", then 500 random bits) and separately asserts the Mealy hit
arrives the same cycle and the Moore hit exactly one cycle later. In
practice: default to Moore for outputs that leave your module; reach for
Mealy when that one cycle genuinely matters.

### FSM style rules this repo now follows

- `localparam` state names; never magic numbers in the case arms.
- Two blocks: sequential state register, combinational next-state logic
  with a **default assignment first** (latch-proof) and a `default:` case
  arm recovering to a sane state.
- Outputs as continuous assigns from state (Moore) or set inside the
  next-state case (Mealy) - but never both styles for one signal.
- Encoding (binary here) is a *suggestion*: Vivado's synthesizer
  re-encodes FSMs as it sees fit (one-hot is its usual pick for small
  machines - check the synthesis log's "FSM Encoding" table in
  `_out/<board>/vivado/*.runs/synth_1/runme.log`). One-hot trades flops
  for simpler next-state logic; binary the reverse. You can pin it with
  `(* fsm_encoding = "one_hot" *)` when you care; mostly you shouldn't.

### The traffic light (the "real project" part)

Requirements that make it non-toy: durations in seconds (ticks), a
pedestrian request that can arrive *any time* and must be remembered, a
guaranteed minimum green for drivers, walk light only during the red it
was served in. The interesting mechanics: a tick-gated FSM (state only
moves on `tick`), a separate timer register cleared on state change, and
two small helper registers (`req_latched`, `serving_walk`) that carry
context across states - the first taste of "FSM + datapath" separation.

`tb_traffic_light.v` checks the full normal cycle, the early-cut path,
the min-green enforcement, and a continuous invariant (exactly one of
green/yellow/red lit; walk implies red) sampled every cycle.

## Simulation

```sh
make sim-all    # tb_sequence_detectors, tb_traffic_light
```

## Hardware demo (`traffic_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

`led[0]`=green, `led[1]`=yellow, `led[2]`=red, `led[3]`=walk; 8s green
(3s minimum), 2s yellow, 6s red. Press the button (Nexys4 BTNC /
BlackBoard BTN0) during a fresh green and count: the light holds the 3s
minimum, goes yellow, and the walk LED lights for the whole red.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
