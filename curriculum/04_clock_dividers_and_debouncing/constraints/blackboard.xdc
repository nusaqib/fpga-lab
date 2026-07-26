## Derived from curriculum/03_flip_flops_and_registers/constraints - same clk,
## btn, led pins (all vendor-verified); sw lines dropped (no sw port here).
set_property PACKAGE_PIN H16 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name pl_clk -period 10.00 -waveform {0 5} [get_ports clk]

set_property PACKAGE_PIN W14 [get_ports btn]
set_property IOSTANDARD LVCMOS33 [get_ports btn]


set_property PACKAGE_PIN N20 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN R19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN T20 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

## Same false-path reasoning as the nexys4 file: async operator inputs,
## human-speed outputs.
set_false_path -from [get_ports btn]
set_false_path -to [get_ports {led[*]}]
