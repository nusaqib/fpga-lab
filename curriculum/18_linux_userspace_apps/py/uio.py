"""Talking to PL registers from Python, two sanctioned-to-scrappy ways.

Uio        - mmap a /dev/uioN the kernel handed us (module 17's binding).
DevMem     - mmap /dev/mem at a physical address. No driver, no isolation,
             root only; the escape hatch when no node is claimed.
dt_find    - read the address straight out of /proc/device-tree, so even
             the escape hatch doesn't hardcode 0xA0000000: the kernel's
             own copy of the device tree is the single source of truth.

Pure stdlib on purpose - this must run on core-image-minimal + python3.
"""

import mmap
import os
import struct


class _Mapped:
    """Common 32-bit register accessors over an mmap'd window."""

    def __init__(self):
        self.mem = None

    def read32(self, off):
        return struct.unpack_from("<I", self.mem, off)[0]

    def write32(self, off, val):
        struct.pack_into("<I", self.mem, off, val & 0xFFFFFFFF)

    def close(self):
        if self.mem is not None:
            self.mem.close()
            self.mem = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


class Uio(_Mapped):
    """One UIO device: found by name, mapped via map0."""

    def __init__(self, n):
        super().__init__()
        base = "/sys/class/uio/uio%d" % n
        with open(base + "/name") as f:
            self.name = f.read().strip()
        with open(base + "/maps/map0/addr") as f:
            self.phys = int(f.read(), 16)
        with open(base + "/maps/map0/size") as f:
            self.size = int(f.read(), 16)
        self.fd = os.open("/dev/uio%d" % n, os.O_RDWR | os.O_SYNC)
        # offset 0 selects map0 (UIO maps sit at page-sized offsets)
        self.mem = mmap.mmap(self.fd, self.size, offset=0)

    @classmethod
    def find(cls, want):
        """First uioN whose sysfs name contains `want`."""
        for n in range(32):
            try:
                with open("/sys/class/uio/uio%d/name" % n) as f:
                    if want in f.read():
                        return cls(n)
            except FileNotFoundError:
                continue
        raise FileNotFoundError(
            "no /dev/uio* named like %r - bitstream loaded? "
            "modprobe uio_pdrv_genirq of_id=<compatible>?" % want)

    def close(self):
        super().close()
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None


class DevMem(_Mapped):
    """A physical window through /dev/mem (root; page-aligned)."""

    def __init__(self, phys, size=0x10000):
        super().__init__()
        page = mmap.PAGESIZE
        if phys % page:
            raise ValueError("phys 0x%x not page-aligned" % phys)
        self.phys, self.size = phys, size
        self.fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
        self.mem = mmap.mmap(self.fd, size, offset=phys)

    def close(self):
        super().close()
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None


def _cells(node_dir, prop, default):
    try:
        with open(os.path.join(node_dir, prop), "rb") as f:
            return struct.unpack(">I", f.read(4))[0]
    except FileNotFoundError:
        return default


def dt_find(name_prefix, root="/proc/device-tree"):
    """Find a device-tree node by name and decode its reg property.

    Returns (phys, size) of the first reg entry of the first node whose
    directory name starts with `name_prefix` (e.g. "axil_regs" matches
    "axil_regs@43c00000"). Cell sizes come from the PARENT node's
    #address-cells/#size-cells, exactly as a DT consumer must do -
    amba_pl is <1,1> on Zynq-7000 but <2,2> on ZynqMP, so hardcoding
    either would break on the other board.
    """
    for parent, dirs, _files in os.walk(root):
        for d in dirs:
            if not d.startswith(name_prefix):
                continue
            node = os.path.join(parent, d)
            try:
                with open(os.path.join(node, "reg"), "rb") as f:
                    reg = f.read()
            except FileNotFoundError:
                continue
            ac = _cells(parent, "#address-cells", 2)
            sc = _cells(parent, "#size-cells", 2)
            words = struct.unpack(">%dI" % (len(reg) // 4), reg)
            phys = 0
            for w in words[:ac]:
                phys = (phys << 32) | w
            size = 0
            for w in words[ac:ac + sc]:
                size = (size << 32) | w
            return phys, size
    raise FileNotFoundError("no DT node starting with %r" % name_prefix)
