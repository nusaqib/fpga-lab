# 05 - Counters and shift registers

**Goal:** the standard register-with-structure zoo - up/down counter,
shift register, ring counter, LFSR - each with the property that actually
matters proven in simulation, plus one switch-selectable hardware demo.

## The concept modules (`hdl/`)

| Module | The property its bench proves |
|---|---|
| `counter_updown.v` | up/down/load/enable with rst > load > en priority, vs a reference model under random stimulus |
| `shift_register.v` | serial-in/parallel-out + parallel load; a loaded word falls out of `serial_out` MSB-first - the seed of UART/SPI |
| `ring_scanner.v` | one-hot bit rotating with wraparound; **self-corrects** from the all-zeros state instead of circulating garbage |
| `lfsr4.v` | maximal-length: period exactly 15, every nonzero state visited once, never hits the all-zeros lockup |
| `scanner_top.v` | hardware demo: switches select which register drives the LEDs |
| `tick_gen.v` | copied from module 04 |

### Power-up initial values - a real FPGA idiom

New this module: registers declared as `output reg [3:0] q = 4'b0001`.
On Xilinx FPGAs that initializer is *synthesizable* - it sets the flop's
INIT value, loaded straight from the bitstream at configuration. That's
why `scanner_top` can tie `rst` low and still come up in a sane state,
and it doubles as protection for the two modules where a bad power-up
state would otherwise be fatal:

- **LFSR lockup**: at all-zeros, the XOR feedback produces zero forever.
  The initializer makes that state unreachable from power-up...
- **...but defense in depth**: `ring_scanner` additionally self-corrects
  *at runtime* if its hot bit ever vanishes (radiation flip, `force` in a
  testbench, integration mistake). Its bench literally `force`s the state
  to all-zeros and checks it recovers.

(ASIC habits differ - there's no configuration bitstream, so explicit
resets carry more weight. Worth knowing which habit you're using and why.)

### The LFSR, briefly

`lfsr4` shifts left and feeds back `q[3] ^ q[2]` (taps for x^4+x^3+1, a
maximal polynomial): a 4-bit register that walks all 15 nonzero states in
a fixed pseudo-random order. LFSRs are hardware's cheap workhorse for
PRBS test patterns, scramblers, and CRC cores. The bench doesn't check "it
looks random" - it checks the *defining* property: back at the seed after
exactly 15 steps, no state repeated, all-zeros never touched.

## Simulation

```sh
make sim-all    # tb_counter_updown, tb_lfsr4, tb_ring_scanner, tb_shift_register
```

New machinery: `force`/`release` in `tb_ring_scanner` - a testbench
reaching into the DUT (`force dut.q = 0`) to create a state the design is
supposed to be *unable* to reach normally, precisely so the recovery path
gets tested. Heavy-handed but the right tool for fault-injection checks.

## Hardware demo (`scanner_top`)

```sh
make BOARD=nexys4 bitstream && make BOARD=nexys4 program
make BOARD=blackboard bitstream
```

Everything advances at ~6Hz; `sw[1:0]` picks what the LEDs show:

| `sw[1:0]` | Display |
|---|---|
| `00` | binary up-counter |
| `01` | ring scanner - one lit LED sweeping (the "Knight Rider") |
| `10` | LFSR - pseudo-random pattern repeating every 15 steps |
| `11` | shift register fed by the LFSR's MSB - bits marching one position per tick |

Watch `10` long enough and you can catch the 15-step repeat with your own
eyes - a period short enough to observe is exactly why the demo uses the
4-bit LFSR rather than a longer one.

## Board status

| Board | Status |
|---|---|
| nexys4 | ready |
| blackboard | ready |
| rfsoc4x2 | deferred until Tier 5 (no free-running PL clock; no constraints file on purpose) |
