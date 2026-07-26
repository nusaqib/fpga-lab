# Block design: a complete AXI-Stream pipeline, observable over JTAG.
#
#   axis_counter_src -> axis_scaler (x3, skid buffer) -> axis_capture
#                                                          ^ AXI4-Lite
#   jtag_axi ---------------------------------------------/
#
# All three stream blocks are our own RTL as module references. A button
# pulse (brought in as a BD port, conditioned outside) fires one packet;
# the capture block's counters/last-value are read over JTAG-AXI exactly
# like module 11's registers.

create_bd_design "axis_pipe_sys"

set src  [create_bd_cell -type module -reference axis_counter_src axis_src_0]
set scl  [create_bd_cell -type module -reference axis_scaler     axis_scaler_0]
set cap  [create_bd_cell -type module -reference axis_capture    axis_cap_0]
set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
set_property CONFIG.PROTOCOL {2} $jtag
set rst  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]

# clock + reset plumbing
create_bd_port -dir I -type clk -freq_hz 100000000 clk
connect_bd_net [get_bd_ports clk] \
    [get_bd_pins axis_src_0/aclk] [get_bd_pins axis_scaler_0/aclk] \
    [get_bd_pins axis_cap_0/aclk] [get_bd_pins jtag_axi_0/aclk] \
    [get_bd_pins rst_0/slowest_sync_clk]

create_bd_port -dir I -type rst resetn
set_property CONFIG.POLARITY {ACTIVE_LOW} [get_bd_ports resetn]
connect_bd_net [get_bd_ports resetn] [get_bd_pins rst_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_0/peripheral_aresetn] \
    [get_bd_pins axis_src_0/aresetn] [get_bd_pins axis_scaler_0/aresetn] \
    [get_bd_pins axis_cap_0/aresetn] [get_bd_pins jtag_axi_0/aresetn]

# the stream pipeline
connect_bd_intf_net [get_bd_intf_pins axis_src_0/m_axis] \
                    [get_bd_intf_pins axis_scaler_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins axis_scaler_0/m_axis] \
                    [get_bd_intf_pins axis_cap_0/s_axis]

# the observation path
connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                    [get_bd_intf_pins axis_cap_0/s_axil]

# start pulse in, beat-counter LEDs out
create_bd_port -dir I start
connect_bd_net [get_bd_ports start] [get_bd_pins axis_src_0/start]
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axis_cap_0/led]

assign_bd_address
set_property offset 0x00000000 [get_bd_addr_segs -quiet {jtag_axi_0/Data/*}]

validate_bd_design
save_bd_design
