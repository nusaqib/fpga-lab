# 27 - A real peripheral, full stack (ADT7420 over I2C, Nexys4)

**Goal:** the syllabus says "a real off-board peripheral, full stack
from constraints to driver." The peripheral of choice is the Nexys4's
on-board ADT7420 temperature sensor - a genuine external chip on a
genuine I2C bus (same electrical and protocol reality as any Pmod
add-on, minus the shipping delay), and this module owns every layer:

```
constraints/nexys4.xdc   the physical pins (F16/G16, vendored source)
hdl/i2c_master.v         the bus protocol, from scratch
hdl/adt7420_reader.v     the "driver": datasheet transactions as an FSM
hdl/temp_top.v           the application: binary -> "T=+025.5C"
hdl/uart_tx.v            the presentation: 115200 8N1, also from scratch
```

No CPU anywhere. Every 500 ms a temperature line arrives in the
terminal, produced entirely by state machines.

## What got learned the hard way (all caught by the bench)

- **Pulling low IS the ACK.** The master's read-ACK was inverted on the
  first pass; the effect was subtle - first byte fine, second byte
  0xFF, and a wedged slave mid-STOP - not an "ACK error" anywhere.
  Exactly how I2C bugs present on real scopes.
- **Nexys4 is not Nexys4-DDR.** The from-memory LED pinout was the
  DDR/A7 one; the vendored master XDC said otherwise. The repo rule
  (never hand-type pins) caught it before the bitstream did.
- **Testbench races are bugs too.** `wait(ready)` immediately after a
  posedge reads pre-NBA state and double-issues; the bench now syncs on
  negedges. (Module 28 makes this class of problem the whole lesson.)

## The bench plays the chip

`sim/tb_adt7420.v` contains a behavioral ADT7420 - address matching,
register pointer, auto-increment, ACK/NACK, driven purely by SCL/SDA
edge events on a `tri1` (pulled-up) bus. Writing the *slave* end is
half the value of the module: a protocol isn't understood until you've
been both sides of it. The bench checks the ID transaction (register
0x0B -> 0xCB), a +25.5C read, then changes the "die temperature" and
expects -10.25C, with `bus_error` low throughout.

Transactions implemented (from the ADT7420 datasheet):

```
identify:  S 4B+W [0x0B] Sr 4B+R [id NACK] P          id_ok if 0xCB
read temp: S 4B+W [0x00] Sr 4B+R [msb ACK] [lsb NACK] P
           temp13 = {msb, lsb[7:3]}   (1/16 degC, 13-bit power-on mode)
```

The repeated START in the middle is the load-bearing detail: pointer
write + data read must be one transaction, or the pointer isn't yours.

## Build & run

```sh
make sim-all              # I2C stack vs the behavioral chip + UART framing
make bitstream program    # Nexys4; terminal at 115200
```

LEDs: raw 13-bit reading on led[12:0], led[15] = ID matched,
led[14] = bus error. Warm the chip with a fingertip and watch both the
LEDs and the decimal readout move.

## Board status

| Board | Status |
|---|---|
| nexys4 | sims pass; bitstream builds; bench run = plug in and watch |
| blackboard / rfsoc4x2 | n/a - their I2C devices hang off the PS (modules 14/15 cover PS peripherals) |
