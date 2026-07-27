# 25 - Gigabit Ethernet (RFSoC4x2, bare-metal lwIP)

**Goal:** a TCP/IP echo server with no operating system - and a clear
view of what a network stack actually is when nothing hides it: a
library (lwIP) that only does things when *your* loop pumps packets
into it and *your* timer pokes its state machines.

## Where Ethernet lives on each board

| Board | Ethernet | Why / why not here |
|---|---|---|
| RFSoC4x2 | **GEM1 (PS-hard MAC) + TI DP83867 PHY, MIO 38-51** | this module |
| BlackBoard | none - the board has no Ethernet jack | n/a |
| Nexys4 | 10/100 PHY on PL pins | needs a fabric MAC + soft CPU: that's module 30 territory, not a PS lesson |

The PL side of this module is nearly empty on purpose (module 13's
blinky, so the board visibly runs while you ping it). GEM-to-PHY wiring
comes entirely from the vendored board preset - RGMII over MIO, MDIO on
50/51. **Zero pin constraints for the actual feature.**

## The software is the module

- **`src/lwip_glue.c`** - lwIP NO_SYS has no clock. Nothing retransmits,
  nothing times out, delayed ACKs never fire unless `tcp_fasttmr()` /
  `tcp_slowtmr()` get called every 250/500 ms. A 50 ms xiltimer tick
  raises flags; the main loop honors them. Skip this and TCP "works"
  right up until the first lost packet - the classic invisible bug.
- **`src/main.c`** - raw-API TCP: no sockets, no threads. A listening
  PCB, an accept callback, a receive callback that `tcp_recved()`s and
  `tcp_write()`s the data straight back. The main loop *is* the OS:
  `xemacif_input()` + timer flags, forever.
- **Build system**: `BSP_LIBS := lwip220` (new vitis.mk/build_app.py
  knob) adds the lwIP library to the platform BSP domain -
  `domain.set_lib()` in the Vitis Python API.

## Build & run

```sh
make bitstream xsa elf
make program                # then run the ELF
```

Wire the board to a host (direct cable is fine - the PHY auto-crosses),
give the host a static address on the same subnet, then:

```sh
ping 192.168.1.10           # ARP + ICMP through the GEM
nc 192.168.1.10 7           # type a line - it comes back
```

UART (115200) shows autonegotiation (`link speed ... 1000`), the IP
config, accepted connections. Board IP is static `192.168.1.10/24`
(DHCP deliberately omitted - no infrastructure dependencies; it's one
BSP option + `dhcp_start()` away if wanted).

## Board status

| Board | Status |
|---|---|
| rfsoc4x2 | bitstream + xsa + elf build; bench run pending (Ethernet cable) |
| blackboard / nexys4 | n/a (see table above) |
