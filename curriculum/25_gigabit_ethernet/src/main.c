/* Module 25: gigabit Ethernet, bare metal - a TCP echo server on lwIP.
 *
 * The GEM (PS-hard gigabit MAC) + TI DP83867 PHY + lwIP in NO_SYS raw
 * mode. Raw mode is the honest way to meet a TCP/IP stack: no sockets,
 * no threads - the stack is a library, packets arrive because the main
 * loop pumps xemacif_input(), TCP state advances because WE call its
 * timers (lwip_glue.c), and "a connection" is a set of callbacks.
 *
 * Test from any host on the same wire:
 *     ping 192.168.1.10
 *     nc 192.168.1.10 7        # type - every line comes back
 */
#include <string.h>
#include "xparameters.h"
#include "netif/xadapter.h"
#include "lwip/init.h"
#include "lwip/inet.h"
#include "lwip/tcp.h"
#include "lwip/priv/tcp_priv.h"
#include "xil_printf.h"
#include "lwip_glue.h"

#ifdef XPAR_XEMACPS_0_BASEADDR
#define EMAC_BASE XPAR_XEMACPS_0_BASEADDR   /* GEM1 on MIO 38-51 (preset) */
#else
#error "no GEM in this XSA - check the PSU preset"
#endif

#define ECHO_PORT 7

static struct netif server_netif;

/* ---------------- the echo application, raw-API style ---------------- */

static err_t echo_recv(void *arg, struct tcp_pcb *tpcb,
                       struct pbuf *p, err_t err)
{
    if (p == NULL) {                    /* remote side closed */
        tcp_close(tpcb);
        tcp_recv(tpcb, NULL);
        xil_printf("echo: connection closed\r\n");
        return ERR_OK;
    }
    /* tell TCP we consumed it, then send it right back */
    tcp_recved(tpcb, p->tot_len);
    if (tcp_sndbuf(tpcb) >= p->tot_len)
        tcp_write(tpcb, p->payload, p->tot_len, TCP_WRITE_FLAG_COPY);
    pbuf_free(p);
    return ERR_OK;
}

static err_t echo_accept(void *arg, struct tcp_pcb *newpcb, err_t err)
{
    xil_printf("echo: connection accepted\r\n");
    tcp_recv(newpcb, echo_recv);
    return ERR_OK;
}

static int echo_start(void)
{
    struct tcp_pcb *pcb = tcp_new_ip_type(IPADDR_TYPE_ANY);
    if (!pcb)
        return -1;
    if (tcp_bind(pcb, IP_ANY_TYPE, ECHO_PORT) != ERR_OK)
        return -1;
    pcb = tcp_listen(pcb);
    if (!pcb)
        return -1;
    tcp_accept(pcb, echo_accept);
    xil_printf("echo server listening on port %d\r\n", ECHO_PORT);
    return 0;
}

/* ---------------------------- bring-up ---------------------------- */

int main(void)
{
    struct netif *netif = &server_netif;
    /* Xilinx OUI + per-board suffix; unique-enough for a lab bench */
    unsigned char mac[] = { 0x00, 0x0a, 0x35, 0x00, 0x25, 0x01 };
    ip_addr_t ip, mask, gw;

    xil_printf("\r\n=== module 25: gigabit Ethernet (lwIP echo, bare metal) ===\r\n");

    lwip_glue_init_timer();
    lwip_init();

    /* xemac_add: MDIO autonegotiation happens in here - it prints the
     * negotiated link speed, or warns if no cable is up */
    if (!xemac_add(netif, NULL, NULL, NULL, mac, EMAC_BASE)) {
        xil_printf("FAIL: could not add network interface\r\n");
        return 1;
    }
    netif_set_default(netif);
    netif_set_up(netif);

    inet_aton("192.168.1.10",  &ip);
    inet_aton("255.255.255.0", &mask);
    inet_aton("192.168.1.1",   &gw);
    netif_set_addr(netif, &ip, &mask, &gw);
    xil_printf("IP: 192.168.1.10  netmask: 255.255.255.0  gw: 192.168.1.1\r\n");

    if (echo_start() != 0) {
        xil_printf("FAIL: could not start echo server\r\n");
        return 1;
    }

    /* the entire "operating system": pump packets, honor timer flags */
    while (1) {
        if (TcpFastTmrFlag) {
            tcp_fasttmr();
            TcpFastTmrFlag = 0;
        }
        if (TcpSlowTmrFlag) {
            tcp_slowtmr();
            TcpSlowTmrFlag = 0;
        }
        xemacif_input(netif);
    }
    return 0;
}
