# Module 13's PSU bring-up, plus M_AXI_GP0 (maxihpm0_fpd), a dual-channel
# AXI GPIO (4 LEDs / 4 buttons), and the GPIO interrupt into pl_ps_irq0.
# Same shape as the BlackBoard file - different silicon, same lesson.

create_bd_design "ps_sys"

set psu [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e psu_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} \
    $psu

set_property -dict [list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__MAXIGP0__DATA_WIDTH {32} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__IRQ0 {1} \
] $psu

set gpio [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_0]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {4}  CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {4} CONFIG.C_ALL_INPUTS_2 {1} \
    CONFIG.C_INTERRUPT_PRESENT {1} \
] $gpio

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
      Master {/psu_0/M_AXI_HPM0_FPD} Slave {/axi_gpio_0/S_AXI} \
      ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0} } \
    [get_bd_intf_pins axi_gpio_0/S_AXI]

connect_bd_net [get_bd_pins axi_gpio_0/ip2intc_irpt] [get_bd_pins psu_0/pl_ps_irq0]

create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axi_gpio_0/gpio_io_o]
create_bd_port -dir I -from 3 -to 0 btn
connect_bd_net [get_bd_ports btn] [get_bd_pins axi_gpio_0/gpio2_io_i]

assign_bd_address
validate_bd_design
save_bd_design
