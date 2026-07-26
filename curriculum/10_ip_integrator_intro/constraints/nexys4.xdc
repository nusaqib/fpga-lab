## clk/led pins as in modules 03-09 (vendor-verified). The 25MHz derived
## clock needs NO manual constraint - the Clocking Wizard/MMCM generates its
## own, propagated from the 100MHz create_clock below.
set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]



set_property PACKAGE_PIN T8 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN V9 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN R8 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN T6 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

## (sync2); sw feeds a register directly but only matters when the operator
## is holding the button, so no timing relationship to the clock is
## meaningful for either. Declaring them false paths keeps timing analysis
## focused on real internal paths.
set_false_path -to [get_ports {led[*]}]
