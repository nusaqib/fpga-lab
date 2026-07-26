# Block design: JTAG-to-AXI master driving our hand-written axil_regs.
#
# jtag_axi is the Tier-4 answer to "who talks AXI before a processor
# exists?": it's an AXI master controlled over the JTAG cable from the
# Vivado Tcl console (create_hw_axi_txn / run_hw_axi) - so the register
# file is poke-able from the host with no CPU anywhere. Tier 5 swaps this
# master for the Zynq PS; axil_regs won't change at all, which is rather
# the point of bus standards.
#
# axil_regs comes in as an RTL MODULE REFERENCE (create_bd_cell -type
# module) - IP integrator wraps the plain Verilog module directly, no
# packaging step. Full ipx packaging (for a reusable IP catalog entry)
# is deliberately deferred; module reference is the lighter-weight tool
# for using your own RTL inside one design.

create_bd_design "jtag_axi_sys"

# our RTL slave (module must already be in the project sources)
set regs [create_bd_cell -type module -reference axil_regs axil_regs_0]

# the JTAG-driven AXI master
set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
set_property CONFIG.PROTOCOL {2} $jtag   ;# 2 = AXI4-Lite

# reset generator (proper synchronized active-low reset for the AXI world)
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]

# clock: straight from the board pin (100MHz), no MMCM needed here
create_bd_port -dir I -type clk -freq_hz 100000000 clk
connect_bd_net [get_bd_ports clk] \
    [get_bd_pins jtag_axi_0/aclk] \
    [get_bd_pins axil_regs_0/aclk] \
    [get_bd_pins rst_0/slowest_sync_clk]

# reset: tie external reset inactive; use the synchronized output
create_bd_port -dir I -type rst resetn
set_property CONFIG.POLARITY {ACTIVE_LOW} [get_bd_ports resetn]
connect_bd_net [get_bd_ports resetn] [get_bd_pins rst_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_0/peripheral_aresetn] \
    [get_bd_pins jtag_axi_0/aresetn] \
    [get_bd_pins axil_regs_0/aresetn]

# the AXI connection itself
connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                    [get_bd_intf_pins axil_regs_0/s_axil]

# board I/O through the BD boundary
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axil_regs_0/led]
create_bd_port -dir I -from 3 -to 0 sw
connect_bd_net [get_bd_ports sw] [get_bd_pins axil_regs_0/sw]
create_bd_port -dir I btn
connect_bd_net [get_bd_ports btn] [get_bd_pins axil_regs_0/btn]

# address map: put the slave at 0x0000_0000, 64K window
assign_bd_address
set_property offset 0x00000000 [get_bd_addr_segs -quiet {jtag_axi_0/Data/*}]

validate_bd_design
save_bd_design
