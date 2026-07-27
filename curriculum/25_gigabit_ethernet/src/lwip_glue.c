/* Timer glue for bare-metal (NO_SYS) lwIP.
 *
 * lwIP's TCP is a pure library with no thread and no clock: unless
 * something calls tcp_fasttmr() every 250 ms and tcp_slowtmr() every
 * 500 ms, retransmissions, delayed ACKs and connection timeouts simply
 * never happen (the stack "works" until the first dropped packet, then
 * hangs - a classic). This file is that something: a 50 ms xiltimer
 * tick that raises flags for the main loop to act on.
 *
 * Adapted from the SDT path of the official lwip220 example glue
 * (Vitis embeddedsw ThirdParty/sw_services/lwip220 examples,
 * lwip_example_platform.c, BSD-3); DHCP hooks dropped - module 25 uses
 * a static IP so the demo has zero infrastructure dependencies.
 */
#include "xiltimer.h"
#include "xinterrupt_wrap.h"
#include "lwip_glue.h"

volatile int TcpFastTmrFlag = 0;
volatile int TcpSlowTmrFlag = 0;

static void tick_50ms(void *ref __attribute__((unused)),
                      u32 tmr __attribute__((unused)))
{
    static int fast = 0, slow = 0;

    if (++fast == 5)  { TcpFastTmrFlag = 1; fast = 0; }
    if (++slow == 10) { TcpSlowTmrFlag = 1; slow = 0; }
}

void lwip_glue_init_timer(void)
{
    XTimer_SetInterval(50);
    XTimer_SetHandler(tick_50ms, 0, XINTERRUPT_DEFAULT_PRIORITY);
}
