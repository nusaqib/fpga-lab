## Identical to curriculum/00_first_bitstream/constraints/blackboard.xdc - reused
## unchanged because every top module here still exposes sw[3:0]/led[3:0].
## Extracted (pins renamed to sw[]/led[] to match hdl/passthrough.v) from
## boards/blackboard/xdc/BlackBoard-RevD-Master.xdc.
## Physical pins are ordinary PL fabric I/O; the upstream file calls them
## PS_GPIO_tri_io[N] because its reference design routes them through a Zynq
## PS EMIO GPIO, but nothing requires that for this PL-only passthrough.
set_property PACKAGE_PIN R17 [get_ports {sw[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
set_property PACKAGE_PIN U20 [get_ports {sw[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
set_property PACKAGE_PIN R16 [get_ports {sw[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[2]}]
set_property PACKAGE_PIN N16 [get_ports {sw[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[3]}]

## LED0 (dedicated ONE_HZ pin) + LED1-3.
set_property PACKAGE_PIN N20 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
set_property PACKAGE_PIN R19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]
set_property PACKAGE_PIN T20 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]
