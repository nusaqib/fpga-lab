## LED pins only, from boards/blackboard/xdc/BlackBoard-RevD-Master.xdc as
## in earlier modules. Deliberately absent: any clock pin (pl_clk comes
## from the PS and carries auto-generated constraints) and any DDR/MIO
## entries (dedicated PS pins - not constrainable, not constrained).
set_property PACKAGE_PIN N20 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN R19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN T20 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_false_path -to [get_ports {led[*]}]
