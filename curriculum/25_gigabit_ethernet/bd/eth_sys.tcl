# Module 25: gigabit Ethernet on the Zynq UltraScale+ PS (RFSoC4x2).
#
# There is almost nothing here, and that IS the module: the GEM (gigabit
# Ethernet MAC) lives in the PS and reaches its TI DP83867 PHY over MIO
# pins 38-51 (ENET1 + MDIO, straight from the vendored board preset). No
# fabric MAC, no AXI plumbing, no pin constraints - the entire network
# stack is software talking to hard silicon. The only PL content is
# module 13's counter blinking LEDs off pl_clk0, so the board visibly
# has a live bitstream while you ping it.

create_bd_design "eth_sys"

set psu [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e psu_0]
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} \
    $psu

# Pure-PS peripheral module: no AXI masters into the PL at all.
set_property -dict [list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
] $psu

set blinky [create_bd_cell -type module -reference ps_blinky_core blinky_0]
connect_bd_net [get_bd_pins psu_0/pl_clk0]    [get_bd_pins blinky_0/pl_clk]
connect_bd_net [get_bd_pins psu_0/pl_resetn0] [get_bd_pins blinky_0/pl_resetn]

create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins blinky_0/led]

validate_bd_design
save_bd_design
