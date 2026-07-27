#!/usr/bin/env python3
"""Module 15's bare-metal demo, now in interactive-speed Python.

Same axil_regs peripheral, same register map, third language this
curriculum has driven it from (C on bare metal, C through UIO, now
Python through the same UIO device). Run on the booted board after
`modprobe uio_pdrv_genirq of_id=xlnx,axil-regs-1.0`.
"""

import sys
import time

from uio import Uio

REG_SCRATCH, REG_LED, REG_STATUS, REG_ID = 0x00, 0x04, 0x08, 0x0C
ID_VALUE = 0xF19A1AB0


def main():
    with Uio.find("axil_regs") as dev:
        print("uio: name=%r phys=0x%x size=0x%x" %
              (dev.name, dev.phys, dev.size))

        ident = dev.read32(REG_ID)
        print("ID      = 0x%08X (%s)" %
              (ident, "ours" if ident == ID_VALUE else "WRONG"))
        if ident != ID_VALUE:
            return 1

        dev.write32(REG_SCRATCH, 0xCAFEF00D)
        print("SCRATCH = 0x%08X" % dev.read32(REG_SCRATCH))
        print("STATUS  = 0x%08X (sw[3:0] + btn[8], live)" %
              dev.read32(REG_STATUS))

        print("walking the LEDs...")
        for i in range(12):
            dev.write32(REG_LED, 1 << (i % 4))
            time.sleep(0.15)
        dev.write32(REG_LED, 0)
    return 0


if __name__ == "__main__":
    sys.exit(main())
