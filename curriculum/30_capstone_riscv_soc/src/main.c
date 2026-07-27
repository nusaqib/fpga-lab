/* Module 30 capstone: a monitor shell on a RISC-V that is made of LUTs.
 *
 * Everything below runs on MicroBlaze-V inside the Artix-7: the CPU,
 * its memory, its bus, and all four peripherals are fabric. The shell
 * exists to prove each piece interactively:
 *
 *   riscv> h              this help
 *   riscv> i              identify: CPU/arch/frequency
 *   riscv> l A5F0         write LEDs (led[14:0]; led[15] is the ISR's)
 *   riscv> s              read switches
 *   riscv> u              uptime, from the timer ISR's tick count
 *   riscv> p 44A00000     peek a word (try the peripherals!)
 *   riscv> m              mirror mode: sw -> led until any key
 *
 * led[15] blinks at 1 Hz from the timer INTERRUPT the whole time -
 * whatever the shell is doing - which is the difference between "a
 * loop that polls" and "a computer".
 */
#include <stdint.h>
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "xstatus.h"
#include "xtmrctr.h"
#include "xuartlite_l.h"
#include "xinterrupt_wrap.h"

#define LED_BASE  XPAR_AXI_GPIO_LED_BASEADDR
#define SW_BASE   XPAR_AXI_GPIO_SW_BASEADDR
#define TMR_BASE  XPAR_AXI_TIMER_0_BASEADDR

#define GPIO_DATA 0x0
#define TICK_HZ   100

static XTmrCtr tmr;
static volatile uint32_t ticks = 0;
static uint16_t led_shadow = 0;

static void set_leds(uint16_t v)
{
    led_shadow = v & 0x7FFF;
    Xil_Out32(LED_BASE + GPIO_DATA,
              led_shadow | ((ticks % TICK_HZ < TICK_HZ / 2) ? 0x8000 : 0));
}

static void timer_isr(void *ref, u8 tmr_num)
{
    (void)ref; (void)tmr_num;
    ticks++;
    /* refresh led[15] heartbeat without touching the shell's bits */
    Xil_Out32(LED_BASE + GPIO_DATA,
              led_shadow | ((ticks % TICK_HZ < TICK_HZ / 2) ? 0x8000 : 0));
}

/* ---------------- tiny line reader + hex parsing ---------------- */

static void read_line(char *buf, int n)
{
    int i = 0;
    for (;;) {
        char c = inbyte();
        if (c == '\r' || c == '\n') {
            outbyte('\r'); outbyte('\n');
            buf[i] = 0;
            return;
        }
        if ((c == 8 || c == 127) && i > 0) {       /* backspace */
            i--;
            xil_printf("\b \b");
            continue;
        }
        if (c >= ' ' && i < n - 1) {
            buf[i++] = c;
            outbyte(c);
        }
    }
}

static int hex_val(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static int parse_hex(const char *s, uint32_t *out)
{
    uint32_t v = 0;
    int any = 0;
    while (*s == ' ') s++;
    while (*s) {
        int d = hex_val(*s);
        if (d < 0) break;
        v = (v << 4) | (uint32_t)d;
        any = 1;
        s++;
    }
    *out = v;
    return any;
}

static const char *skip_word(const char *s)
{
    while (*s == ' ') s++;
    while (*s && *s != ' ') s++;
    return s;
}

/* ---------------- the shell ---------------- */

int main(void)
{
    char line[64];
    uint32_t v;

    xil_printf("\r\n=== module 30: RISC-V SoC on Nexys4 (MicroBlaze-V) ===\r\n");

    if (XTmrCtr_Initialize(&tmr, TMR_BASE) != XST_SUCCESS) {
        xil_printf("timer init failed\r\n");
        return 1;
    }
    XTmrCtr_SetHandler(&tmr, timer_isr, &tmr);
    XTmrCtr_SetOptions(&tmr, 0,
                       XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
    XTmrCtr_SetResetValue(&tmr, 0, 0xFFFFFFFF - (XPAR_AXI_TIMER_0_CLOCK_FREQUENCY / TICK_HZ));
    if (XSetupInterruptSystem(&tmr, XTmrCtr_InterruptHandler,
                              tmr.Config.IntrId, tmr.Config.IntrParent,
                              XINTERRUPT_DEFAULT_PRIORITY) != XST_SUCCESS) {
        xil_printf("interrupt setup failed\r\n");
        return 1;
    }
    XTmrCtr_Start(&tmr, 0);
    xil_printf("timer ISR live: led[15] is the heartbeat\r\n");
    xil_printf("type 'h' for help\r\n");

    for (;;) {
        xil_printf("riscv> ");
        read_line(line, sizeof(line));
        switch (line[0]) {
        case 0:
            break;
        case 'h':
            xil_printf("  i          identify\r\n");
            xil_printf("  l <hex>    write led[14:0]\r\n");
            xil_printf("  s          read switches\r\n");
            xil_printf("  u          uptime\r\n");
            xil_printf("  p <addr>   peek 32-bit word\r\n");
            xil_printf("  w <a> <v>  poke 32-bit word\r\n");
            xil_printf("  m          mirror sw->led until keypress\r\n");
            break;
        case 'i':
            xil_printf("MicroBlaze-V (RV32) at %d MHz, 128KB local BRAM\r\n",
                       XPAR_AXI_TIMER_0_CLOCK_FREQUENCY / 1000000);
            xil_printf("this CPU is made of LUTs.\r\n");
            break;
        case 'l':
            if (parse_hex(line + 1, &v)) {
                set_leds((uint16_t)v);
                xil_printf("led[14:0] = 0x%04x\r\n", (unsigned)(v & 0x7FFF));
            } else
                xil_printf("usage: l <hex>\r\n");
            break;
        case 's':
            xil_printf("sw = 0x%04x\r\n",
                       (unsigned)(Xil_In32(SW_BASE + GPIO_DATA) & 0xFFFF));
            break;
        case 'u': {
            uint32_t t = ticks;
            xil_printf("uptime %d.%02d s (%d ticks at %d Hz, all ISR-counted)\r\n",
                       t / TICK_HZ, (t % TICK_HZ) * 100 / TICK_HZ, t, TICK_HZ);
            break;
        }
        case 'p':
            if (parse_hex(line + 1, &v)) {
                xil_printf("[%08x] = %08x\r\n", (unsigned)v,
                           (unsigned)Xil_In32(v));
            } else
                xil_printf("usage: p <addr>\r\n");
            break;
        case 'w': {
            uint32_t a, d;
            const char *rest = skip_word(line + 1);
            if (parse_hex(line + 1, &a) && parse_hex(rest, &d)) {
                Xil_Out32(a, d);
                xil_printf("[%08x] <= %08x\r\n", (unsigned)a, (unsigned)d);
            } else
                xil_printf("usage: w <addr> <val>\r\n");
            break;
        }
        case 'm':
            xil_printf("mirroring (module 00, but with a CPU) - any key stops\r\n");
            while (XUartLite_IsReceiveEmpty(XPAR_AXI_UARTLITE_0_BASEADDR))
                set_leds((uint16_t)Xil_In32(SW_BASE + GPIO_DATA));
            (void)inbyte();
            break;
        default:
            xil_printf("? (h for help)\r\n");
        }
    }
    return 0;
}
