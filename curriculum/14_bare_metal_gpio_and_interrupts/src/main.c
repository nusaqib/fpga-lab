/*
 * Module 14 - bare-metal GPIO and interrupts.
 *
 * What runs where, after thirteen modules of pure hardware: this file runs
 * on the ARM core inside the Zynq (Cortex-A9 on BlackBoard, Cortex-A53 on
 * RFSoC4x2), compiled against the BSP that Vitis generated from this
 * module's exported .xsa. The LEDs and buttons it touches are the same
 * physical pins module 00 drove with wires - now they're registers at an
 * AXI address, reached through the PS's M_AXI_GP0 port.
 *
 * Two ways of noticing a button, demonstrated side by side:
 *   1. polling (the main loop reads the GPIO every pass), used here only
 *      to spot-print state changes;
 *   2. interrupts: the AXI GPIO raises ip2intc_irpt -> PS fabric
 *      interrupt -> GIC -> our handler runs, no polling anywhere. The
 *      handler advances the LED pattern; main() mostly sleeps in wfi.
 *
 * SDT flow notes (2026.1 generates -DSDT BSPs): drivers are addressed by
 * base address instead of the old device IDs, and interrupt wiring goes
 * through the xinterrupt_wrap helpers using the IntrId/IntrParent fields
 * the BSP put into the driver config from the hardware description.
 */

#include <stdio.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xgpio.h"
#include "xinterrupt_wrap.h"
#include "sleep.h"

#define GPIO_BASEADDR   XPAR_XGPIO_0_BASEADDR
#define LED_CHANNEL     1
#define BTN_CHANNEL     2

static XGpio gpio;
static volatile u32 press_events = 0;

static void btn_isr(void *ref)
{
    XGpio *g = (XGpio *)ref;

    /* ack first: clear the channel-2 interrupt in the AXI GPIO */
    (void)XGpio_InterruptClear(g, XGPIO_IR_CH2_MASK);

    /* count only presses (any button newly down), ignore releases */
    if (XGpio_DiscreteRead(g, BTN_CHANNEL) != 0) {
        press_events++;
        XGpio_DiscreteWrite(g, LED_CHANNEL, press_events & 0xF);
    }
}

int main(void)
{
    int status;

    xil_printf("\r\n== fpga-lab module 14: bare-metal GPIO + interrupts ==\r\n");
    xil_printf("core: %s\r\n",
#ifdef ARMA53_64
               "Cortex-A53 (RFSoC4x2)"
#else
               "Cortex-A9 (BlackBoard)"
#endif
    );

    status = XGpio_Initialize(&gpio, GPIO_BASEADDR);
    if (status != XST_SUCCESS) {
        xil_printf("XGpio_Initialize failed (%d)\r\n", status);
        return status;
    }
    XGpio_SetDataDirection(&gpio, LED_CHANNEL, 0x0);  /* outputs */
    XGpio_SetDataDirection(&gpio, BTN_CHANNEL, 0xF);  /* inputs  */

    /* prove plain register-level GPIO first: walk the LEDs once */
    for (int i = 0; i < 8; i++) {
        XGpio_DiscreteWrite(&gpio, LED_CHANNEL, 1u << (i % 4));
        usleep(100000);
    }
    XGpio_DiscreteWrite(&gpio, LED_CHANNEL, 0x0);
    xil_printf("LED walk done - GPIO writes reach the pins.\r\n");

    /* interrupt plumbing: GIC setup + AXI GPIO channel-2 interrupts on.
     * The interrupt id/parent live in the CONFIG struct (filled in from
     * the hardware description), not the driver instance - look it up. */
    XGpio_Config *cfg = XGpio_LookupConfig(GPIO_BASEADDR);
    if (cfg == NULL) {
        xil_printf("XGpio_LookupConfig failed\r\n");
        return XST_FAILURE;
    }
    status = XSetupInterruptSystem(&gpio, (void *)btn_isr,
                                   cfg->IntrId, cfg->IntrParent,
                                   XINTERRUPT_DEFAULT_PRIORITY);
    if (status != XST_SUCCESS) {
        xil_printf("XSetupInterruptSystem failed (%d)\r\n", status);
        return status;
    }
    XGpio_InterruptEnable(&gpio, XGPIO_IR_CH2_MASK);
    XGpio_InterruptGlobalEnable(&gpio);

    xil_printf("Interrupts armed - press buttons; LEDs count presses.\r\n");

    u32 last_reported = 0;
    while (1) {
        if (press_events != last_reported) {
            last_reported = press_events;
            xil_printf("press event #%lu (btn=0x%lx)\r\n",
                       (unsigned long)last_reported,
                       (unsigned long)XGpio_DiscreteRead(&gpio, BTN_CHANNEL));
        }
        /* nothing to do until the next interrupt */
        __asm__ volatile("wfi");
    }

    return 0;
}
