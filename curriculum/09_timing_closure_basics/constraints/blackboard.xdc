## Same clk/sw/led pins as module 05 (vendor-verified, see modules 00-08).
set_property PACKAGE_PIN H16 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name pl_clk -period 10.00 -waveform {0 5} [get_ports clk]


set_property PACKAGE_PIN R17 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN U20 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN R16 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN N16 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

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
set_false_path -from [get_ports {sw[*]}]
set_false_path -to [get_ports {led[*]}]

## The multicycle path in mcp_example: source and capture registers are
## both enabled once every 4 cycles, so the triple-multiply cloud between
## them truthfully has 4 clock periods for setup (and hold is checked one
## cycle behind the relaxed setup edge, per the standard -hold N-1
## companion). Scoped to the mcp instance so the pipelined chain next to
## it stays under normal single-cycle analysis.
set_multicycle_path -setup 4 -from [get_pins -hier -filter {NAME =~ *u_mcp/x_r_reg*/C}] -to [get_pins -hier -filter {NAME =~ *u_mcp/result_reg*/D}]
set_multicycle_path -hold  3 -from [get_pins -hier -filter {NAME =~ *u_mcp/x_r_reg*/C}] -to [get_pins -hier -filter {NAME =~ *u_mcp/result_reg*/D}]
