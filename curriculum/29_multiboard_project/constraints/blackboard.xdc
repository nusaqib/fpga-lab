## Pins verbatim from boards/blackboard/xdc/BlackBoard-RevD-Master.xdc:
## 100MHz PL oscillator H16, Pmod JB1/JB2 (D19/D20), LEDs LD0-3.
set_property PACKAGE_PIN H16 [get_ports CLK100_IN]
set_property IOSTANDARD LVCMOS33 [get_ports CLK100_IN]
create_clock -period 10.000 -name gclk [get_ports CLK100_IN]

set_property PACKAGE_PIN D19 [get_ports jb1_txd]
set_property IOSTANDARD LVCMOS33 [get_ports jb1_txd]
set_property PACKAGE_PIN D20 [get_ports jb2_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports jb2_rxd]

set_property PACKAGE_PIN N20 [get_ports {led[0]}]
set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property PACKAGE_PIN R19 [get_ports {led[2]}]
set_property PACKAGE_PIN T20 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports jb1_txd]
set_false_path -from [get_ports jb2_rxd]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
