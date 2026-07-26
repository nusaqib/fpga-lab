# RFSoC4x2 flavor of module 15: same custom axil_regs slave, PSU master.

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
] $psu

set regs [create_bd_cell -type module -reference axil_regs axil_regs_0]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
    { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
      Master {/psu_0/M_AXI_HPM0_FPD} Slave {/axil_regs_0/s_axil} \
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
# the BSP not emit an XPAR macro for a module-reference block).
set_property offset 0xA0000000 [get_bd_addr_segs -quiet -of_objects [get_bd_addr_spaces -quiet -filter {NAME =~ "*Data*" || NAME =~ "*HPM0*"}]]
validate_bd_design
save_bd_design
