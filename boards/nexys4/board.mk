# Digilent Nexys4 (original, Artix-7, non-DDR variant). If you actually have
# a Nexys4 DDR, see the note in docs/README.md before trusting pin numbers -
# the two boards share a family name but not a pinout.
FPGA_PART  := xc7a100tcsg324-1
BOARD_PART := digilentinc.com:nexys4:part0:1.1
BOARD_CLOCK_PORT_HINT      := clk
BOARD_CLOCK_PERIOD_NS_HINT := 10.0
