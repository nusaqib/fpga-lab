# Module 13's PS7 bring-up, plus the pieces module 14 is about:
#  - M_AXI_GP0 switched back on: the PS's window into PL address space,
#  - a dual-channel AXI GPIO (ch1: 4 LEDs out, ch2: 4 buttons in) hung off
#    it via connection automation,
#  - the GPIO's interrupt line into the PS fabric-interrupt input
#    (IRQ_F2P) - software stops polling and starts sleeping.

create_bd_design "ps_sys"

set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7_0]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $ps7

set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP0 {0} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
] $ps7

set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {4}  CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {4} CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_INTERRUPT_PRESENT {1} \
] $gpio

# Connection automation: builds the AXI interconnect + proc_sys_reset and
# clocks everything from FCLK_CLK0.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
      Master {/ps7_0/M_AXI_GP0} Slave {/axi_gpio_0/S_AXI} \
      ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0} } \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

connect_bd_net [get_bd_pins axi_gpio_0/ip2intc_irpt] [get_bd_pins ps7_0/IRQ_F2P]

create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axi_gpio_0/gpio_io_o]
create_bd_port -dir I -from 3 -to 0 btn
connect_bd_net [get_bd_ports btn] [get_bd_pins axi_gpio_0/gpio2_io_i]

assign_bd_address
validate_bd_design
save_bd_design
