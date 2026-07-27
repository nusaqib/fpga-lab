# Bring-up LEDs (run / rf_gate / fb_gate / saturation), copied verbatim
# from boards/rfsoc4x2/xdc/4x2_LED_PB__SW.xdc (W_LED_0..3), renamed to
# this design's led[3:0] port. RF pins are dedicated package pins routed
# by the RFDC IP itself - no constraints needed or allowed for them.
set_property PACKAGE_PIN AR11 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]
set_property PACKAGE_PIN AW10 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]
set_property PACKAGE_PIN AT11 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[2]}]
set_property PACKAGE_PIN AU10 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[3]}]
