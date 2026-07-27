#!/usr/bin/env python3
"""Module 24's SDR receive path, driven from Python on Linux - the tier's
payoff. Bare metal needed a recompile-and-JTAG cycle per experiment; here
you set the DDS tone, capture, and read a spectrum at a shell prompt.

Hardware: module 24's sdr_sys bitstream (dds_hls TX -> DAC_A, ADC_A ->
axis_snap_iq), SMA cable DAC_A -> ADC_A. Register maps below are from
hdl/axis_snap_iq.v and the packaged dds_hls IP - offsets within each
block; the BASE addresses are discovered from /proc/device-tree at
runtime (dt_find), not hardcoded.

Prerequisite the minimal image does NOT yet cover: the RF clock chain
(LMK/LMX over SPI) and RFDC tile/mixer setup that module 24's bare-metal
main.c performs. Until that init is ported to Linux (rfdc has a proper
Linux userspace stack - the PYNQ route), run this after the tiles are up.
The capture/FFT machinery itself has no such dependency: with the DDS
running it will show SOMETHING; where the peak lands tells you about the
mixer state - which is itself instructive.

Uses /dev/mem, not UIO: uio_pdrv_genirq claims ONE compatible per load,
and this design has three distinct blocks. One-off UIO is for one device;
a subsystem wants either DT-discovered /dev/mem (this) or a real driver.
"""

import cmath
import sys

from uio import DevMem, dt_find

# axis_snap_iq (hdl/axis_snap_iq.v)
SNAP_ID, SNAP_CTRL, SNAP_STATUS, SNAP_DEPTH = 0x0000, 0x0004, 0x0008, 0x000C
SNAP_BUF = 0x8000
SNAP_ID_VALUE = 0xACE00024
N_BEATS = 1024                 # 8 complex samples per 32-byte beat

# dds_hls (xdds_hls_hw.h from the packaged HLS IP)
DDS_PHASE_INC = 0x10

DAC_BB_MSPS = 1228.8           # DDS output sample rate (module 24)
ADC_BB_MSPS = 2457.6           # captured complex sample rate
NFFT = 1024


def dds_set_mhz(dds, f_off):
    inc = int(f_off / DAC_BB_MSPS * 4294967296.0)
    dds.write32(DDS_PHASE_INC, inc & 0xFFFFFFFF)


def capture(snap):
    snap.write32(SNAP_CTRL, 1)
    while (snap.read32(SNAP_STATUS) & 1) == 0:
        pass
    x = []
    for b in range(N_BEATS):
        beat = [snap.read32(SNAP_BUF + b * 32 + w * 4) for w in range(8)]
        for w in range(4):                    # words 0-3 I, 4-7 Q
            iv, qv = beat[w], beat[4 + w]
            for half in (0, 16):
                i = (iv >> half) & 0xFFFF
                q = (qv >> half) & 0xFFFF
                i -= 0x10000 if i >= 0x8000 else 0
                q -= 0x10000 if q >= 0x8000 else 0
                x.append(complex(i, q))
    return x


def spectrum_peak_mhz(x):
    """Peak bin of an NFFT-point FFT, DC bins excluded (module 24's rule).

    Plain O(n^2)-free radix-2 via cmath; at 1024 points pure Python is
    instant, no numpy needed on the minimal image.
    """
    n = NFFT
    a = list(x[:n])
    j = 0
    for i in range(1, n):                     # bit-reverse permute
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    m = 2
    while m <= n:
        wm = cmath.exp(-2j * cmath.pi / m)
        for k in range(0, n, m):
            w = 1.0 + 0j
            for t in range(m // 2):
                u, v = a[k + t], a[k + t + m // 2] * w
                a[k + t], a[k + t + m // 2] = u + v, u - v
                w *= wm
        m <<= 1
    best, mag = 0, -1.0
    for k in range(n):
        if min(k, n - k) <= 3:                # exclude DC leakage bins
            continue
        p = abs(a[k])
        if p > mag:
            best, mag = k, p
    f = best if best < n // 2 else best - n
    return f * ADC_BB_MSPS / n, mag


def main():
    snap_phys, snap_size = dt_find("axis_snap_iq")
    dds_phys, dds_size = dt_find("dds_hls")
    print("snap @ 0x%x (+0x%x), dds @ 0x%x (+0x%x)  [from /proc/device-tree]"
          % (snap_phys, snap_size, dds_phys, dds_size))

    tones = [float(t) for t in sys.argv[1:]] or [240.0, -240.0, 480.0]
    with DevMem(snap_phys, snap_size) as snap, \
         DevMem(dds_phys, dds_size) as dds:
        ident = snap.read32(SNAP_ID)
        if ident != SNAP_ID_VALUE:
            print("snap ID 0x%08X != 0x%08X - wrong bitstream?"
                  % (ident, SNAP_ID_VALUE))
            return 1
        for t in tones:
            dds_set_mhz(dds, t)
            x = capture(snap)
            f, mag = spectrum_peak_mhz(x)
            print("tone %+9.3f MHz -> peak %+9.3f MHz (|X|=%.0f)"
                  % (t, f, mag))
    return 0


if __name__ == "__main__":
    sys.exit(main())
