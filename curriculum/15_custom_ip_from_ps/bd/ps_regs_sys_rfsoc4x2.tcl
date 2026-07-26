# RFSoC4x2 flavor of module 15: same custom axil_regs slave, PSU master.
#
# Unlike the BlackBoard file, the AXI plumbing here is wired BY HAND:
# connection automation, pointed at a module-reference slave on this PS,
# chose to insert a Clocking Wizard with a dangling input (found via
# validate_bd_design in a standalone run). Explicit beats clever - and
# it's more instructive anyway: this is everything automation does,
# spelled out.

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
set rst  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]
set sc   [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect sc_0]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $sc

# one clock (pl_clk0) drives everything, including the PS's own M_AXI port
connect_bd_net [get_bd_pins psu_0/pl_clk0] \
    [get_bd_pins psu_0/maxihpm0_fpd_aclk] \
    [get_bd_pins sc_0/aclk] \
    [get_bd_pins rst_0/slowest_sync_clk] \
    [get_bd_pins axil_regs_0/aclk]

connect_bd_net [get_bd_pins psu_0/pl_resetn0] [get_bd_pins rst_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_0/peripheral_aresetn] \
    [get_bd_pins sc_0/aresetn] \
    [get_bd_pins axil_regs_0/aresetn]

connect_bd_intf_net [get_bd_intf_pins psu_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins sc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_0/M00_AXI] \
                    [get_bd_intf_pins axil_regs_0/s_axil]

create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axil_regs_0/led]
create_bd_port -dir I -from 3 -to 0 sw
connect_bd_net [get_bd_ports sw] [get_bd_pins axil_regs_0/sw]
create_bd_port -dir I btn
connect_bd_net [get_bd_ports btn] [get_bd_pins axil_regs_0/btn]

assign_bd_address
# Deterministic base address (matches the fallback in src/main.c should
# the BSP not emit an XPAR macro for a module-reference block). Range
# first: a full-aperture segment can't be moved (see blackboard file).
set seg [get_bd_addr_segs -filter {NAME =~ "*axil_regs*"}]
if {[llength $seg] != 1} { error "expected exactly one axil_regs segment, got '$seg'" }
set_property range 64K $seg
set_property offset 0xA0000000 $seg
validate_bd_design
save_bd_design
