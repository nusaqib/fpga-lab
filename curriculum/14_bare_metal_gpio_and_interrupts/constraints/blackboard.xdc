## LED0-3 + BTN0-3 from boards/blackboard/xdc/BlackBoard-RevD-Master.xdc.
## No clock pin: everything is on PS-generated FCLK_CLK0.
set_property PACKAGE_PIN N20 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN R19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN T20 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN W14 [get_ports {btn[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[0]}]
set_property PACKAGE_PIN W13 [get_ports {btn[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[1]}]
set_property PACKAGE_PIN P15 [get_ports {btn[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[2]}]
set_property PACKAGE_PIN M14 [get_ports {btn[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[3]}]

set_false_path -to [get_ports {led[*]}]
set_false_path -from [get_ports {btn[*]}]
