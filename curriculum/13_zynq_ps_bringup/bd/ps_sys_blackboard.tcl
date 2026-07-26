# Block design: BlackBoard's Zynq-7000 processing system, minimally alive.
#
# processing_system7 is the hard silicon: two Cortex-A9s, DDR3 controller,
# UART, SD, USB - none of it consumes a single LUT. What the PL gets from
# it here is the thing this whole curriculum has been waiting for on this
# board's Zynq sibling: FCLK_CLK0, a PS-generated 100MHz fabric clock.
#
# Block automation ("apply_board_preset 1") pulls the DDR3 timings and MIO
# pinout from the VENDORED board files (boards/blackboard/board_files,
# made visible via board.repoPaths) - the same hardware truth used by
# RealDigital's own reference design, not hand-typed PCW_* values. It also
# wires the DDR and FIXED_IO interfaces out to external ports; those are
# dedicated pins, so no XDC entries exist for them.

create_bd_design "ps_sys"

set ps7 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7_0]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    $ps7

# Trim to bring-up essentials: one 100MHz fabric clock, no AXI masters yet
# (module 14 turns M_AXI_GP0 back on to talk to PL peripherals).
set_property -dict [list \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_M_AXI_GP0 {0} \
] $ps7

# FCLK_CLK0 + a synchronized reset out to the PL
create_bd_port -dir O -type clk pl_clk
connect_bd_net [get_bd_ports pl_clk] [get_bd_pins ps7_0/FCLK_CLK0]

set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]
connect_bd_net [get_bd_pins ps7_0/FCLK_CLK0] [get_bd_pins rst_0/slowest_sync_clk]
connect_bd_net [get_bd_pins ps7_0/FCLK_RESET0_N] [get_bd_pins rst_0/ext_reset_in]
create_bd_port -dir O pl_resetn
connect_bd_net [get_bd_ports pl_resetn] [get_bd_pins rst_0/peripheral_aresetn]

validate_bd_design
save_bd_design
