/* RF clock chain bring-up for RFSoC4x2, bare metal.
 *
 * On the PYNQ image this is done by the xrfclk Python package through
 * /dev/spidev; here it's the same three chips, same register values, same
 * write protocol - just XSpiPs instead of spidev. Topology (from the
 * board's device tree, vendored in boards/rfsoc4x2/rfclk/):
 *
 *   PS SPI0 CS0 -> LMK04828  system clock generator (245.76 MHz refs)
 *   PS SPI0 CS1 -> LMX2594   RF synth, DAC tiles (491.52 MHz sample ref)
 *   PS SPI0 CS2 -> LMX2594   RF synth, ADC tiles (491.52 MHz sample ref)
 *
 * All transfers are 24-bit MSB-first, SPI mode 0. Register values come
 * from the vendored TICS exports via scripts/tics_to_header.py - never
 * hand-typed (same rule as pin constraints).
 */
#include <stdint.h>
#include "xparameters.h"
#include "xspips.h"
#include "sleep.h"
#include "xil_printf.h"
#include "rfclk.h"
#include "rfclk_regs.h"

#define LMK_CS  0U
#define LMX_DAC_CS 1U
#define LMX_ADC_CS 2U

static XSpiPs spi;

static int spi_write24(uint32_t val)
{
    u8 buf[3] = { (u8)(val >> 16), (u8)(val >> 8), (u8)val };
    return XSpiPs_PolledTransfer(&spi, buf, NULL, 3);
}

static int write_lmk(void)
{
    XSpiPs_SetSlaveSelect(&spi, LMK_CS);
    for (unsigned i = 0; i < sizeof(LMK04828_REGS) / 4; i++) {
        if (spi_write24(LMK04828_REGS[i]) != XST_SUCCESS)
            return XST_FAILURE;
    }
    return XST_SUCCESS;
}

/* xrfclk's LMX protocol: RESET=1, RESET=0, all registers R112..R0 in file
 * order, then R0 once more (after VCO cal settles) with FCAL_EN set. */
static int write_lmx(u8 cs)
{
    const unsigned n = sizeof(LMX2594_REGS) / 4;

    XSpiPs_SetSlaveSelect(&spi, cs);
    if (spi_write24(0x020000) != XST_SUCCESS) return XST_FAILURE;
    if (spi_write24(0x000000) != XST_SUCCESS) return XST_FAILURE;
    for (unsigned i = 0; i < n; i++) {
        if (spi_write24(LMX2594_REGS[i]) != XST_SUCCESS)
            return XST_FAILURE;
    }
    usleep(10000);                       /* let the VCO calibrate */
    return spi_write24(LMX2594_REGS[n - 1]);   /* R0 again, from stable state */
}

int rfclk_program(void)
{
    XSpiPs_Config *cfg = XSpiPs_LookupConfig(XPAR_XSPIPS_0_BASEADDR);
    if (cfg == NULL) {
        xil_printf("rfclk: no SPI config found\r\n");
        return XST_FAILURE;
    }
    if (XSpiPs_CfgInitialize(&spi, cfg, cfg->BaseAddress) != XST_SUCCESS)
        return XST_FAILURE;

    /* Master, CS held asserted for the whole (3-byte) transfer, mode 0.
     * 200 MHz SPI ref / 64 = 3.125 MHz SCK - far below what the TI parts
     * accept, comfortably above painful. */
    XSpiPs_SetOptions(&spi, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
    XSpiPs_SetClkPrescaler(&spi, XSPIPS_CLK_PRESCALE_64);

    xil_printf("rfclk: LMK04828 (%d regs)... ", sizeof(LMK04828_REGS) / 4);
    if (write_lmk() != XST_SUCCESS) { xil_printf("FAILED\r\n"); return XST_FAILURE; }
    xil_printf("ok\r\n");
    usleep(10000);   /* LMK PLL2 lock before handing its clock to the LMXs */

    xil_printf("rfclk: LMX2594 DAC (CS%d)... ", LMX_DAC_CS);
    if (write_lmx(LMX_DAC_CS) != XST_SUCCESS) { xil_printf("FAILED\r\n"); return XST_FAILURE; }
    xil_printf("ok\r\n");

    xil_printf("rfclk: LMX2594 ADC (CS%d)... ", LMX_ADC_CS);
    if (write_lmx(LMX_ADC_CS) != XST_SUCCESS) { xil_printf("FAILED\r\n"); return XST_FAILURE; }
    xil_printf("ok\r\n");

    return XST_SUCCESS;
}
