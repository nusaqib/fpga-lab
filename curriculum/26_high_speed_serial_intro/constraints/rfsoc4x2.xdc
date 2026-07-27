# QSFP28 GTY refclk: GTY_128_REF_CLK_QSFP at AA33/AA34, 156.25 MHz.
# Source: RealDigital RFSoC 4x2 Reference Manual Rev A3, Appendix A
# (and independently confirmed: Vivado assigns MGTREFCLK0_128 to the
# same package pins). The 8 lane pins need no constraints - they are
# fixed by the quad choice inside the IBERT IP.
set_property PACKAGE_PIN AA33 [get_ports gty_refclk0p_i]
set_property PACKAGE_PIN AA34 [get_ports gty_refclk0n_i]
create_clock -name gtrefclk0_128 -period 6.4 [get_ports gty_refclk0p_i]
set_clock_groups -group [get_clocks gtrefclk0_128 -include_generated_clocks] -asynchronous

# QSFP module sideband (LVCMOS18, from boards/rfsoc4x2/xdc/4x2_QSFP.xdc):
# hold a plugged module out of reset and in full-power mode.
set_property PACKAGE_PIN AL21 [get_ports qsfp_resetl]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_resetl]
set_property PACKAGE_PIN AN22 [get_ports qsfp_lpmode]
set_property IOSTANDARD LVCMOS18 [get_ports qsfp_lpmode]
set_false_path -to [get_ports qsfp_resetl]
set_false_path -to [get_ports qsfp_lpmode]

# Debug hub runs on the 156.25 MHz sysclk (from the IBERT example XDC).
set_property C_CLK_INPUT_FREQ_HZ 156250000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER true [get_debug_cores dbg_hub]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
