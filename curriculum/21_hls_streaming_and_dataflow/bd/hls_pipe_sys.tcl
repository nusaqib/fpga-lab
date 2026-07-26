# Module 12's stream pipeline with the hand-written scaler swapped for the
# PACKAGED HLS IP - the integration this module exists to prove:
#
#   axis_counter_src (16b) -> fir_decim_hls (HLS, FIR + decimate-by-2)
#                          -> axis_capture (AXI4-Lite window, jtag_axi)
#
# The HLS IP arrives via ip_repo_paths from this module's own _out
# (path exported by the Makefile as FPGA_LAB_HLS_IP; run
# `make hls-package` before the first bitstream build).

if {![info exists ::env(FPGA_LAB_HLS_IP)] || ![file isdirectory $::env(FPGA_LAB_HLS_IP)]} {
    error "FPGA_LAB_HLS_IP not set or missing - run 'make hls-package' first"
}
set_property ip_repo_paths [list $::env(FPGA_LAB_HLS_IP)] [current_project]
update_ip_catalog

create_bd_design "hls_pipe_sys"

set src  [create_bd_cell -type module -reference axis_counter_src axis_src_0]
set_property CONFIG.WIDTH {16} $src
set hlsk [create_bd_cell -type ip -vlnv xilinx.com:hls:fir_decim_hls:1.0 fir_decim_0]
set cap  [create_bd_cell -type module -reference axis_capture axis_cap_0]
set jtag [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi jtag_axi_0]
set_property CONFIG.PROTOCOL {2} $jtag
set rst  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_0]

create_bd_port -dir I -type clk -freq_hz 100000000 clk
connect_bd_net [get_bd_ports clk] \
    [get_bd_pins axis_src_0/aclk] [get_bd_pins fir_decim_0/ap_clk] \
    [get_bd_pins axis_cap_0/aclk] [get_bd_pins jtag_axi_0/aclk] \
    [get_bd_pins rst_0/slowest_sync_clk]

create_bd_port -dir I -type rst resetn
set_property CONFIG.POLARITY {ACTIVE_LOW} [get_bd_ports resetn]
connect_bd_net [get_bd_ports resetn] [get_bd_pins rst_0/ext_reset_in]
connect_bd_net [get_bd_pins rst_0/peripheral_aresetn] \
    [get_bd_pins axis_src_0/aresetn] [get_bd_pins fir_decim_0/ap_rst_n] \
    [get_bd_pins axis_cap_0/aresetn] [get_bd_pins jtag_axi_0/aresetn]

connect_bd_intf_net [get_bd_intf_pins axis_src_0/m_axis] \
                    [get_bd_intf_pins fir_decim_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins fir_decim_0/m_axis] \
                    [get_bd_intf_pins axis_cap_0/s_axis]

connect_bd_intf_net [get_bd_intf_pins jtag_axi_0/M_AXI] \
                    [get_bd_intf_pins axis_cap_0/s_axil]

create_bd_port -dir I start
connect_bd_net [get_bd_ports start] [get_bd_pins axis_src_0/start]
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axis_cap_0/led]

assign_bd_address
set_property offset 0x00000000 [get_bd_addr_segs -quiet {jtag_axi_0/Data/*}]

validate_bd_design
save_bd_design
