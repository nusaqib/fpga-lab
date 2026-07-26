/*
 * Module 15 - the processor drives OUR hardware.
 *
 * No Xilinx driver exists for axil_regs, because we invented it. This is
 * the whole lesson: a "driver" for a memory-mapped peripheral is nothing
 * but reads and writes at base + offset, exactly the transactions module
 * 11 issued from the JTAG Tcl console and module 12's capture block
 * answered - now issued by C code through the PS's M_AXI port.
 *
 * The register map comes from hdl/axil_regs.v (single source of truth):
 *   0x00 SCRATCH RW | 0x04 LED RW | 0x08 STATUS RO (sw[3:0], btn[8]) |
 *   0x0C ID RO = 0xF19A1AB0
 *
 * The program is a self-checking exercise of all four, PASS/FAIL over
 * UART - the on-silicon equivalent of tb_axil_regs.v.
 */

#include "xil_printf.h"
#include "xil_io.h"
#include "xparameters.h"
#include "sleep.h"

/* Prefer the BSP-discovered address; module-reference RTL blocks don't
 * always get an XPAR macro (no driver to hang it on), so fall back to the
 * address the BD script pins deliberately (see bd/*.tcl). */
#ifdef XPAR_AXIL_REGS_0_BASEADDR
#define REGS_BASE       XPAR_AXIL_REGS_0_BASEADDR
#elif defined(ARMA53_64)
#define REGS_BASE       0xA0000000u    /* PSU M_AXI_HPM0_FPD window */
#else
#define REGS_BASE       0x43C00000u    /* PS7 M_AXI_GP0 window */
#endif

#define REG_SCRATCH     0x00u
#define REG_LED         0x04u
#define REG_STATUS      0x08u
#define REG_ID          0x0Cu
#define EXPECTED_ID     0xF19A1AB0u

static u32 rd(u32 off)          { return Xil_In32(REGS_BASE + off); }
static void wr(u32 off, u32 v)  { Xil_Out32(REGS_BASE + off, v); }

int main(void)
{
    int errors = 0;

    xil_printf("\r\n== fpga-lab module 15: custom IP from the PS ==\r\n");

    /* 1. discovery: is our peripheral where the address map says? */
    u32 id = rd(REG_ID);
    xil_printf("ID register: 0x%08lx %s\r\n", (unsigned long)id,
               id == EXPECTED_ID ? "(ours!)" : "(WRONG)");
    if (id != EXPECTED_ID) errors++;

    /* 2. scratch: write/readback walking patterns */
    static const u32 patterns[] = {
        0x00000000u, 0xFFFFFFFFu, 0xA5A5A5A5u, 0x5A5A5A5Au, 0xDEADBEEFu
    };
    for (unsigned i = 0; i < sizeof(patterns)/sizeof(patterns[0]); i++) {
        wr(REG_SCRATCH, patterns[i]);
        u32 back = rd(REG_SCRATCH);
        if (back != patterns[i]) {
            errors++;
            xil_printf("SCRATCH FAIL: wrote 0x%08lx read 0x%08lx\r\n",
                       (unsigned long)patterns[i], (unsigned long)back);
        }
    }
    xil_printf("scratch write/readback done\r\n");

    /* 3. LEDs: walk the pattern through our own register */
    for (int i = 0; i < 12; i++) {
        wr(REG_LED, 1u << (i % 4));
        usleep(150000);
    }
    wr(REG_LED, 0x0);
    xil_printf("LED walk done (via axil_regs, not axi_gpio)\r\n");

    /* 4. STATUS is live hardware state - report it periodically */
    xil_printf(errors ? "RESULT: FAIL (%d errors)\r\n" : "RESULT: PASS\r\n",
               errors);
    xil_printf("now mirroring switches to LEDs via software...\r\n");
    while (1) {
        u32 status = rd(REG_STATUS);
        wr(REG_LED, status & 0xF);          /* sw -> led, through the CPU */
        if (status & (1u << 8))
            xil_printf("button down (STATUS=0x%03lx)\r\n",
                       (unsigned long)status);
        usleep(50000);
    }

    return 0;
}
