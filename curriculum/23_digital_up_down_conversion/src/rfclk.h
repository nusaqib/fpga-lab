#ifndef RFCLK_H
#define RFCLK_H

/* Program the RFSoC4x2's RF clock chain (LMK04828 + 2x LMX2594) over PS
 * SPI0. Must run before the RFDC tiles can leave reset - without it the
 * tiles have no sample clock at all. Returns XST_SUCCESS/XST_FAILURE. */
int rfclk_program(void);

#endif
