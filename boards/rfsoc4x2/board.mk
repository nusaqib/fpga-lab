# RealDigital RFSoC4x2 (Zynq UltraScale+ RFSoC, distributed via Digilent /
# AMD University Program). Part string and board_part id are copied verbatim
# from the vendored board_files/rfsoc4x2/1.0/board.xml - do not hand-retype
# these, they are speed-grade sensitive.
FPGA_PART  := xczu48dr-ffvg1517-2-e
BOARD_PART := realdigital.org:rfsoc4x2:part0:1.0

# No single fixed PL fabric clock pin exists on this board for a PL-only
# design: pl_clk0 is normally sourced from the Zynq PS (see docs/README.md).
# Bring-up modules that need PL logic before the PS/Vitis stage is introduced
# should drive their flip-flops from a debounced pushbutton edge instead.
