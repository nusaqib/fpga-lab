#ifndef LWIP_GLUE_H
#define LWIP_GLUE_H

/* TCP housekeeping timer glue (see lwip_glue.c). */
extern volatile int TcpFastTmrFlag;   /* set every 250 ms */
extern volatile int TcpSlowTmrFlag;   /* set every 500 ms */

void lwip_glue_init_timer(void);

#endif
