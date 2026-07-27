# 29 - Two boards, one wire: a multiboard heartbeat link

**Goal:** make two physically separate FPGAs - different boards,
different parts, different oscillators - talk to each other, with the
same RTL on both ends. Each board broadcasts a 4-byte heartbeat twice a
second and displays the *other* board's counter on its LEDs. Two link
LEDs, two counters, one crossed cable: distributed systems at their
smallest.

## The protocol (all four bytes of it)

```
[0xA5] [my_id] [counter] [sum]        sum = 0xA5 + id + counter (mod 256)
```

- **Why a sync byte AND a checksum:** 0xA5 can appear as data, so a
  parser can lock onto the middle of a packet. The checksum rejects
  those, and the parser re-hunts - which is why even toy protocols need
  integrity checks, not just magic bytes. (Grown-up links escape or
  line-code instead - module 26's 64b/66b discussion.)
- **Why a heartbeat + timeout is all the state you need:** `link_up` =
  "a valid packet arrived within 3 beat periods." Cut the cable, it
  drops; reconnect, it heals. No handshake, no sequence numbers, no
  stored state to corrupt.
- **Why two boards with independent crystals can talk at all:** the
  UART receiver (new `hdl/uart_rx.v`) synchronizes the line (module
  03's two flops), finds the start edge, then samples mid-bit - the
  mid-bit landing tolerates a few percent of clock mismatch. The bench
  runs the two nodes at 100.00 vs 100.30 MHz on purpose.

## Simulation is the whole system

`tb_link.v` instantiates BOTH boards and a breakable, corruptible
"cable", then walks the link's life: bring-up (IDs on the right sides,
counters advancing), a corrupted byte (checksum eats it, link stays),
a cable cut (both ends drop on timeout), reconnect (self-heal). Four
phases, each printed, one PASS.

## Hardware run

```sh
make BOARD=nexys4 bitstream program
make BOARD=blackboard bitstream program
```

Wire (both boards powered off first):

| Nexys4 JA | dir | BlackBoard JB |
|---|---|---|
| JA1 (B13, TX) | -> | JB2 (D20, RX) |
| JA2 (F14, RX) | <- | JB1 (D19, TX) |
| GND | -- | GND |

GND-to-GND is not optional: two boards on separate USB supplies share
no reference until you give them one. Both are 3.3V banks (verified in
the vendored constraint files) - levels match.

Expect: both link LEDs on (Nexys4 led[15], BlackBoard led[3]), the
Nexys4's led[7:0] counting at the BlackBoard's pace and vice versa.
Pull the cable: links drop within ~1.5s. Replug: they heal.

**RFSoC4x2 note:** its Pmod+ signals sit on an LVCMOS18 bank while the
connector's Vdd pins are 3.3V, and the reference manual does not state
whether the signal pins are level-shifted. Until that's verified from
the schematic, wiring it to a 3.3V Pmod is an unmanaged electrical
risk, so this module deliberately ships no RFSoC variant -
hardware-truthfulness applies to volts as much as to pins. (TODO if a
verified answer surfaces.)

## Board status

| Board | Status |
|---|---|
| nexys4 | sim green (as half of the pair); bitstream builds |
| blackboard | sim green (other half); bitstream builds |
| rfsoc4x2 | deliberately omitted - unverified Pmod signal voltage (see note) |
