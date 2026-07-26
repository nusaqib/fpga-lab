# Block design: RFSoC4x2's Zynq UltraScale+ processing system - and with
# it, the moment this board has waited thirteen modules for: pl_clk0, its
# first usable PL fabric clock (see boards/rfsoc4x2/docs/README.md for why
# none existed before).
#
# zynq_ultra_ps_e is a different, bigger beast than the 7-series PS (four
# A53s + two R5s, DDR4, the RF converter clocking infrastructure), but the
# bring-up shape is identical - which is the lesson of doing both boards
# in one module. Block automation applies the preset from the VENDORED
# board files (boards/rfsoc4x2/board_files): DDR4 config, MIO, clocks,
# exactly as RealDigital defined them.

create_bd_design "ps_sys"

set psu [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e psu_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} \
    $psu

# Bring-up essentials: pl_clk0 at 100MHz, no AXI masters yet (module 14).
set_property -dict [list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
] $psu

create_bd_port -dir O -type clk pl_clk
connect_bd_net [get_bd_ports pl_clk] [get_bd_pins psu_0/pl_clk0]

set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]
connect_bd_net [get_bd_pins psu_0/pl_clk0] [get_bd_pins rst_0/slowest_sync_clk]
connect_bd_net [get_bd_pins psu_0/pl_resetn0] [get_bd_pins rst_0/ext_reset_in]
create_bd_port -dir O pl_resetn
connect_bd_net [get_bd_ports pl_resetn] [get_bd_pins rst_0/peripheral_aresetn]

validate_bd_design
save_bd_design
