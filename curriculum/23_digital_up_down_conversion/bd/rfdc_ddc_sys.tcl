# Module 23: SAME hardware as module 22's loopback - deliberately. The
# whole point of this module is that mixers, NCOs and decimation are
# RUNTIME properties of the RFDC: one bitstream, many radios. All the
# DUC/DDC action lives in src/main.c; see module 22's bd/ for the
# block-by-block commentary on this design.

create_bd_design "rfdc_sys"

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

# --- RF data converter: tile-2 pair only, config values from PYNQ base ---
set rfdc [create_bd_cell -type ip -vlnv xilinx.com:ip:usp_rf_data_converter rfdc]
set_property -dict [list \
    CONFIG.ADC_Slice00_Enable {false} \
    CONFIG.ADC_Slice02_Enable {false} \
    CONFIG.DAC_Slice00_Enable {false} \
    CONFIG.ADC2_Outclk_Freq {307.200} \
    CONFIG.ADC2_PLL_Enable {true} \
    CONFIG.ADC2_Refclk_Freq {491.520} \
    CONFIG.ADC2_Sampling_Rate {4.9152} \
    CONFIG.ADC_Slice22_Enable {true} \
    CONFIG.ADC_Data_Type22 {1} \
    CONFIG.ADC_Data_Width22 {8} \
    CONFIG.ADC_Decimation_Mode22 {2} \
    CONFIG.ADC_Mixer_Mode22 {0} \
    CONFIG.ADC_Mixer_Type22 {2} \
    CONFIG.DAC2_Outclk_Freq {307.200} \
    CONFIG.DAC2_PLL_Enable {true} \
    CONFIG.DAC2_Refclk_Freq {491.520} \
    CONFIG.DAC2_Sampling_Rate {4.9152} \
    CONFIG.DAC_Slice20_Enable {true} \
    CONFIG.DAC_Interpolation_Mode20 {2} \
    CONFIG.DAC_Mixer_Mode20 {0} \
    CONFIG.DAC_Mixer_Type20 {2} \
] $rfdc

# --- fabric blocks (module references) ---
set src  [create_bd_cell -type module -reference dc_source dc_source_0]
set snap [create_bd_cell -type module -reference axis_snap axis_snap_0]

set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect sc_0]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {2} CONFIG.NUM_CLKS {2}] $sc

set rst_pl  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_pl0]
set rst_adc [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_adc2]
set rst_dac [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_dac2]

# --- clocks ---
# pl_clk0 (100M): PS master port, SmartConnect S-side, RFDC register file
connect_bd_net [get_bd_pins psu_0/pl_clk0] \
    [get_bd_pins psu_0/maxihpm0_fpd_aclk] \
    [get_bd_pins sc_0/aclk] \
    [get_bd_pins rst_pl0/slowest_sync_clk] \
    [get_bd_pins rfdc/s_axi_aclk]
# clk_adc2 (307.2M from the tile): ADC stream + snapshot block + SC M-side
connect_bd_net [get_bd_pins rfdc/clk_adc2] \
    [get_bd_pins rfdc/m2_axis_aclk] \
    [get_bd_pins axis_snap_0/aclk] \
    [get_bd_pins sc_0/aclk1] \
    [get_bd_pins rst_adc2/slowest_sync_clk]
# clk_dac2 (307.2M): DAC stream side
connect_bd_net [get_bd_pins rfdc/clk_dac2] \
    [get_bd_pins rfdc/s2_axis_aclk] \
    [get_bd_pins dc_source_0/aclk] \
    [get_bd_pins rst_dac2/slowest_sync_clk]

# --- resets (one synchronizer per clock domain, all from pl_resetn0) ---
connect_bd_net [get_bd_pins psu_0/pl_resetn0] \
    [get_bd_pins rst_pl0/ext_reset_in] \
    [get_bd_pins rst_adc2/ext_reset_in] \
    [get_bd_pins rst_dac2/ext_reset_in]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] \
    [get_bd_pins sc_0/aresetn] \
    [get_bd_pins rfdc/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_adc2/peripheral_aresetn] \
    [get_bd_pins rfdc/m2_axis_aresetn] \
    [get_bd_pins axis_snap_0/aresetn]
connect_bd_net [get_bd_pins rst_dac2/peripheral_aresetn] \
    [get_bd_pins rfdc/s2_axis_aresetn] \
    [get_bd_pins dc_source_0/aresetn]

# --- AXI ---
connect_bd_intf_net [get_bd_intf_pins psu_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins sc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_0/M00_AXI] \
                    [get_bd_intf_pins rfdc/s_axi]
connect_bd_intf_net [get_bd_intf_pins sc_0/M01_AXI] \
                    [get_bd_intf_pins axis_snap_0/s_axil]

# --- streams ---
connect_bd_intf_net [get_bd_intf_pins dc_source_0/m_axis] \
                    [get_bd_intf_pins rfdc/s20_axis]
# ADC block: m22 = I, m23 = Q. Record I; Q left unconnected on purpose.
connect_bd_intf_net [get_bd_intf_pins rfdc/m22_axis] \
                    [get_bd_intf_pins axis_snap_0/s_axis]

# --- RF pins out to the package (dedicated pins - no XDC anywhere) ---
foreach port {dac2_clk adc2_clk sysref_in vout20 vin2_23} {
    set pin [get_bd_intf_pins rfdc/$port]
    create_bd_intf_port -mode [get_property MODE $pin] \
        -vlnv [get_property VLNV $pin] $port
    connect_bd_intf_net [get_bd_intf_ports $port] $pin
}

# --- addresses: deterministic, range before offset (module 15's lesson) ---
assign_bd_address
set rfdc_seg [get_bd_addr_segs -filter {NAME =~ "*rfdc*"}]
if {[llength $rfdc_seg] != 1} { error "expected exactly one rfdc segment, got '$rfdc_seg'" }
set_property offset 0xA0000000 $rfdc_seg
set snap_seg [get_bd_addr_segs -filter {NAME =~ "*axis_snap*"}]
if {[llength $snap_seg] != 1} { error "expected exactly one axis_snap segment, got '$snap_seg'" }
set_property range 64K $snap_seg
set_property offset 0xA0100000 $snap_seg

validate_bd_design
save_bd_design
