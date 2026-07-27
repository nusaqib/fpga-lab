/*
 * uio_regs - drive module 15's axil_regs peripheral from Linux userspace
 * through UIO. The Linux twin of module 15's bare-metal src/main.c: same
 * register map, but instead of Xil_Out32 at a hardcoded address in a
 * flat address space, we ask the KERNEL for the device.
 *
 * How the pieces connect (the whole point of this module):
 *
 *   axil_regs in the block design
 *     -> sdtgen writes a node for it into pl.dtsi (addr/size from the BD)
 *     -> our dts/uio-axil-regs.dtsi overrides its compatible to "generic-uio"
 *     -> the uio_pdrv_genirq driver (with of_id=generic-uio on the kernel
 *        command line) claims the node and exposes /dev/uioN
 *     -> this program mmaps /dev/uioN and pokes the same registers
 *
 * No hardcoded 0xA0000000 anywhere here: the physical address travels
 * BD -> device tree -> kernel -> sysfs, and we just read the map size
 * from /sys/class/uio/uioN/maps/map0/size. That indirection is the
 * device-tree lesson in one program.
 *
 * Register map (from hdl/axil_regs.v):
 *   0x00 SCRATCH RW   0x04 LED RW [3:0]   0x08 STATUS RO   0x0C ID RO
 */
#include <fcntl.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define REG_SCRATCH 0x00
#define REG_LED     0x04
#define REG_STATUS  0x08
#define REG_ID      0x0C
#define ID_VALUE    0xF19A1AB0u

/* Find the uio node whose name matches our device by scanning sysfs.
 * Each /sys/class/uio/uioN/name holds the DT node name the driver bound
 * to (e.g. "axil_regs"). Returns N, or -1. */
static int find_uio(const char *want, char *name_out, size_t name_len)
{
    for (int n = 0; n < 32; n++) {
        char path[64], name[64];
        snprintf(path, sizeof path, "/sys/class/uio/uio%d/name", n);
        FILE *f = fopen(path, "r");
        if (!f)
            continue;
        if (fgets(name, sizeof name, f)) {
            name[strcspn(name, "\n")] = 0;
            if (strstr(name, want)) {
                fclose(f);
                snprintf(name_out, name_len, "%s", name);
                return n;
            }
        }
        fclose(f);
    }
    return -1;
}

static uint64_t read_sysfs_hex(int n, const char *leaf)
{
    char path[96];
    snprintf(path, sizeof path, "/sys/class/uio/uio%d/maps/map0/%s", n, leaf);
    FILE *f = fopen(path, "r");
    if (!f)
        return 0;
    uint64_t v = 0;
    if (fscanf(f, "%" SCNx64, &v) != 1)
        v = 0;
    fclose(f);
    return v;
}

int main(int argc, char **argv)
{
    const char *want = (argc > 1) ? argv[1] : "axil_regs";
    char name[64];

    int n = find_uio(want, name, sizeof name);
    if (n < 0) {
        fprintf(stderr,
                "no /dev/uio* named like '%s'.\n"
                "Checklist: is the bitstream loaded? does pl.dtsi's node carry\n"
                "compatible=\"generic-uio\"? is uio_pdrv_genirq.of_id=generic-uio\n"
                "on the kernel command line (cat /proc/cmdline)?\n",
                want);
        return 1;
    }

    uint64_t phys = read_sysfs_hex(n, "addr");
    uint64_t size = read_sysfs_hex(n, "size");
    printf("uio%d: name=\"%s\" phys=0x%llx size=0x%llx\n", n, name,
           (unsigned long long)phys, (unsigned long long)size);
    if (size == 0)
        size = 0x10000;

    char dev[32];
    snprintf(dev, sizeof dev, "/dev/uio%d", n);
    int fd = open(dev, O_RDWR | O_SYNC);
    if (fd < 0) {
        perror(dev);
        return 1;
    }

    /* offset 0 = map0; UIO maps are selected by page-sized offsets */
    volatile uint32_t *regs =
        mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (regs == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    uint32_t id = regs[REG_ID / 4];
    printf("ID      = 0x%08X (%s)\n", id,
           id == ID_VALUE ? "correct - this is our peripheral" : "WRONG");
    if (id != ID_VALUE)
        return 1;

    regs[REG_SCRATCH / 4] = 0xCAFEF00D;
    printf("SCRATCH = 0x%08X (wrote 0xCAFEF00D)\n", regs[REG_SCRATCH / 4]);
    printf("STATUS  = 0x%08X (sw[3:0] + btn[8], live)\n",
           regs[REG_STATUS / 4]);

    printf("walking the LEDs...\n");
    for (int i = 0; i < 12; i++) {
        regs[REG_LED / 4] = 1u << (i % 4);
        usleep(150 * 1000);
    }
    regs[REG_LED / 4] = 0;

    munmap((void *)regs, size);
    close(fd);
    printf("done.\n");
    return 0;
}
