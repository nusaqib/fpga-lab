## Identical to curriculum/00_first_bitstream/constraints/rfsoc4x2.xdc - reused
## unchanged because every top module here still exposes sw[3:0]/led[3:0].
## Extracted (pins renamed to sw[]/led[] to match hdl/passthrough.v) from
## boards/rfsoc4x2/xdc/4x2_LED_PB__SW.xdc (SW_0-3, W_LED_0-3).
set_property PACKAGE_PIN AN13 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[0]}]
set_property PACKAGE_PIN AU12 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[1]}]
set_property PACKAGE_PIN AW11 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[2]}]
set_property PACKAGE_PIN AV11 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {sw[3]}]

set_property PACKAGE_PIN AR11 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]
set_property PACKAGE_PIN AW10 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]
set_property PACKAGE_PIN AT11 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[2]}]
set_property PACKAGE_PIN AU10 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[3]}]

## Board-wide recommended config, per the vendored constraint file.
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
