## W_LED_0-3 + PB_0-3 from boards/rfsoc4x2/xdc/4x2_LED_PB__SW.xdc.
## No clock pin: everything is on PS-generated pl_clk0.
set_property PACKAGE_PIN AR11 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]
set_property PACKAGE_PIN AW10 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]
set_property PACKAGE_PIN AT11 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[2]}]
set_property PACKAGE_PIN AU10 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[3]}]

set_property PACKAGE_PIN AV12 [get_ports {btn[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {btn[0]}]
set_property PACKAGE_PIN AV10 [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {btn[1]}]
set_property PACKAGE_PIN AW9 [get_ports {btn[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {btn[2]}]
set_property PACKAGE_PIN AT12 [get_ports {btn[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {btn[3]}]

set_false_path -to [get_ports {led[*]}]
set_false_path -from [get_ports {btn[*]}]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
