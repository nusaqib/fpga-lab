/*
 * devmem_regs - module 17's uio_regs, minus the driver: raw /dev/mem.
 *
 * Same axil_regs peripheral, same checks, but the kernel grants us the
 * whole physical address space and trusts us with it. This exists to
 * make the contrast with UIO concrete:
 *   - root only, and one stray offset can scribble on ANY device;
 *   - no interrupt support, ever (UIO gives you a blocking read());
 *   - CONFIG_STRICT_DEVMEM (on in most distro kernels, often off in
 *     embedded ones) silently forbids the RAM range and can bite MMIO;
 *   - and nothing tells you which address to use - so at least we make
 *     the caller pass it explicitly instead of baking one in. Get it
 *     from the device tree on the target:
 *       ls -d /proc/device-tree/amba_pl/axil_regs@*   (base in the name)
 *
 * Usage: devmem_regs 0x43c00000        (BlackBoard; 0xA0000000 RFSoC4x2)
 */
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

#define MAP_SIZE 0x10000
#define ID_VALUE 0xF19A1AB0u

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s <phys-base-from-device-tree>\n", argv[0]);
        return 2;
    }
    uint64_t phys = strtoull(argv[1], NULL, 0);
    long page = sysconf(_SC_PAGESIZE);
    if (phys % (uint64_t)page) {
        fprintf(stderr, "0x%llx is not page-aligned\n",
                (unsigned long long)phys);
        return 2;
    }

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        perror("/dev/mem (root?)");
        return 1;
    }
    volatile uint32_t *regs = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE,
                                   MAP_SHARED, fd, (off_t)phys);
    if (regs == MAP_FAILED) {
        perror("mmap (CONFIG_STRICT_DEVMEM?)");
        return 1;
    }

    uint32_t id = regs[0x0C / 4];
    printf("ID      = 0x%08X (%s)\n", id, id == ID_VALUE ? "ours" : "WRONG");
    if (id != ID_VALUE)
        return 1;
    regs[0x00 / 4] = 0xCAFEF00D;
    printf("SCRATCH = 0x%08X\n", regs[0x00 / 4]);
    printf("STATUS  = 0x%08X\n", regs[0x08 / 4]);
    for (int i = 0; i < 12; i++) {
        regs[0x04 / 4] = 1u << (i % 4);
        usleep(150 * 1000);
    }
    regs[0x04 / 4] = 0;

    munmap((void *)regs, MAP_SIZE);
    close(fd);
    printf("done.\n");
    return 0;
}
