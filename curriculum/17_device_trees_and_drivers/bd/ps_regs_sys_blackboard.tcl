# Module 11's custom AXI4-Lite register block, now owned by the processor:
# same axil_regs RTL (copied verbatim into this module), same register map,
# but hanging off the PS's M_AXI_GP0 instead of a JTAG-AXI debug master.
# What was a Tcl-console poke in module 11 becomes a C driver in module 15.

create_bd_design "ps_sys"

set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7_0]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $ps7

set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {0} \
] $ps7

set regs [create_bd_cell -type module -reference axil_regs axil_regs_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
      Master {/ps7_0/M_AXI_GP0} Slave {/axil_regs_0/s_axil} \
      ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0} } \
    [get_bd_intf_pins axil_regs_0/s_axil]

create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axil_regs_0/led]
create_bd_port -dir I -from 3 -to 0 sw
connect_bd_net [get_bd_ports sw] [get_bd_pins axil_regs_0/sw]
create_bd_port -dir I btn
connect_bd_net [get_bd_ports btn] [get_bd_pins axil_regs_0/btn]

assign_bd_address
# Deterministic base address (matches the fallback in src/main.c should
# the BSP not emit an XPAR macro for a module-reference block). Select the
# segment by the slave's name and insist on exactly one match - a -quiet
# getter feeding set_property an empty list kills the whole script.
set seg [get_bd_addr_segs -filter {NAME =~ "*axil_regs*"}]
if {[llength $seg] != 1} { error "expected exactly one axil_regs segment, got '$seg'" }
# Range first: auto-assignment gives the segment the whole master aperture
# (1G), and a 1G-range segment can only start at the aperture base - the
# offset write fails with BD 41-70 until the range is shrunk.
set_property range 64K $seg
set_property offset 0x43C00000 $seg
validate_bd_design
save_bd_design
