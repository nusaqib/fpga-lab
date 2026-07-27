# LLRF system: module 24's RFDC plumbing (tile 2, DAC_A/ADC_A, values
# from PYNQ base) around llrf_core, with wave_snap diagnostics buffers
# teed off both streams.
#
#   ADC_A -> fine mixer (NCO -f_RF) -> combiner -> broadcaster
#       -> llrf_core (mean/dec/rotate/PI/pulse_gen) -> broadcaster
#       -> DAC fine mixer (NCO +f_RF) -> DAC_A
#   and one wave_snap on each broadcaster's second leg.
#
# One deliberate departure from module 24: the DAC fabric interface is
# clocked from clk_adc2, not clk_dac2. A feedback loop must live in one
# clock domain; both tiles' fabric rates are 307.2 MHz, and the RFDC's
# s/m_axis clock inputs accept any clock at the right frequency. (The
# unused clk_dac2 output just stays unconnected.)

create_bd_design "llrf_sys"

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

# RFDC: identical tile-2 pair to modules 22/23/24 (values from PYNQ base)
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

# --- the LLRF core and its diagnostics ---
set core [create_bd_cell -type module -reference llrf_core llrf_core_0]

set comb [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_combiner comb_iq]

set bc_adc [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster bc_adc]
set_property -dict [list CONFIG.NUM_MI {2} \
    CONFIG.M_TDATA_NUM_BYTES {32} CONFIG.S_TDATA_NUM_BYTES {32} \
    CONFIG.M00_TDATA_REMAP {tdata[255:0]} CONFIG.M01_TDATA_REMAP {tdata[255:0]} \
] $bc_adc
set bc_dac [create_bd_cell -type ip -vlnv xilinx.com:ip:axis_broadcaster bc_dac]
set_property -dict [list CONFIG.NUM_MI {2} \
    CONFIG.M_TDATA_NUM_BYTES {16} CONFIG.S_TDATA_NUM_BYTES {16} \
    CONFIG.M00_TDATA_REMAP {tdata[127:0]} CONFIG.M01_TDATA_REMAP {tdata[127:0]} \
] $bc_dac

set snap_adc [create_bd_cell -type module -reference wave_snap snap_adc]
set_property -dict [list CONFIG.DATA_W {256} CONFIG.ID_VALUE {0xACE011F1}] $snap_adc
set snap_dac [create_bd_cell -type module -reference wave_snap snap_dac]
set_property -dict [list CONFIG.DATA_W {128} CONFIG.ID_VALUE {0xACE011F2}] $snap_dac

set sc [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect sc_0]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {4} CONFIG.NUM_CLKS {2}] $sc

set rst_pl  [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_pl0]
set rst_adc [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset rst_adc2]

set zero [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant ext_trig_0]
set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] $zero

# --- clocks: everything RF-side lives on clk_adc2 (one loop, one domain) ---
connect_bd_net [get_bd_pins psu_0/pl_clk0] \
    [get_bd_pins psu_0/maxihpm0_fpd_aclk] \
    [get_bd_pins sc_0/aclk] \
    [get_bd_pins rst_pl0/slowest_sync_clk] \
    [get_bd_pins rfdc/s_axi_aclk]
connect_bd_net [get_bd_pins rfdc/clk_adc2] \
    [get_bd_pins rfdc/m2_axis_aclk] \
    [get_bd_pins rfdc/s2_axis_aclk] \
    [get_bd_pins comb_iq/aclk] \
    [get_bd_pins bc_adc/aclk] \
    [get_bd_pins bc_dac/aclk] \
    [get_bd_pins llrf_core_0/aclk] \
    [get_bd_pins snap_adc/aclk] \
    [get_bd_pins snap_dac/aclk] \
    [get_bd_pins sc_0/aclk1] \
    [get_bd_pins rst_adc2/slowest_sync_clk]

# --- resets ---
connect_bd_net [get_bd_pins psu_0/pl_resetn0] \
    [get_bd_pins rst_pl0/ext_reset_in] \
    [get_bd_pins rst_adc2/ext_reset_in]
connect_bd_net [get_bd_pins rst_pl0/peripheral_aresetn] \
    [get_bd_pins sc_0/aresetn] \
    [get_bd_pins rfdc/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_adc2/peripheral_aresetn] \
    [get_bd_pins rfdc/m2_axis_aresetn] \
    [get_bd_pins rfdc/s2_axis_aresetn] \
    [get_bd_pins comb_iq/aresetn] \
    [get_bd_pins bc_adc/aresetn] \
    [get_bd_pins bc_dac/aresetn] \
    [get_bd_pins llrf_core_0/aresetn] \
    [get_bd_pins snap_adc/aresetn] \
    [get_bd_pins snap_dac/aresetn]

# --- AXI ---
connect_bd_intf_net [get_bd_intf_pins psu_0/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins sc_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins sc_0/M00_AXI] \
                    [get_bd_intf_pins rfdc/s_axi]
connect_bd_intf_net [get_bd_intf_pins sc_0/M01_AXI] \
                    [get_bd_intf_pins llrf_core_0/s_axil]
connect_bd_intf_net [get_bd_intf_pins sc_0/M02_AXI] \
                    [get_bd_intf_pins snap_adc/s_axil]
connect_bd_intf_net [get_bd_intf_pins sc_0/M03_AXI] \
                    [get_bd_intf_pins snap_dac/s_axil]

# --- streams ---
connect_bd_intf_net [get_bd_intf_pins rfdc/m22_axis] \
                    [get_bd_intf_pins comb_iq/S00_AXIS]
connect_bd_intf_net [get_bd_intf_pins rfdc/m23_axis] \
                    [get_bd_intf_pins comb_iq/S01_AXIS]
connect_bd_intf_net [get_bd_intf_pins comb_iq/M_AXIS] \
                    [get_bd_intf_pins bc_adc/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins bc_adc/M00_AXIS] \
                    [get_bd_intf_pins llrf_core_0/s_axis]
connect_bd_intf_net [get_bd_intf_pins bc_adc/M01_AXIS] \
                    [get_bd_intf_pins snap_adc/s_axis]
connect_bd_intf_net [get_bd_intf_pins llrf_core_0/m_axis] \
                    [get_bd_intf_pins bc_dac/S_AXIS]
connect_bd_intf_net [get_bd_intf_pins bc_dac/M00_AXIS] \
                    [get_bd_intf_pins rfdc/s20_axis]
connect_bd_intf_net [get_bd_intf_pins bc_dac/M01_AXIS] \
                    [get_bd_intf_pins snap_dac/s_axis]

# --- pulse trigger to the capture buffers; external trigger tied off ---
connect_bd_net [get_bd_pins llrf_core_0/trig_out] \
    [get_bd_pins snap_adc/hw_trig] \
    [get_bd_pins snap_dac/hw_trig]
connect_bd_net [get_bd_pins ext_trig_0/dout] [get_bd_pins llrf_core_0/ext_trig]

# --- bring-up LEDs ---
create_bd_port -dir O -from 3 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins llrf_core_0/led]

# --- RF pins out to the package (dedicated - no XDC) ---
foreach port {dac2_clk adc2_clk sysref_in vout20 vin2_23} {
    set pin [get_bd_intf_pins rfdc/$port]
    create_bd_intf_port -mode [get_property MODE $pin] \
        -vlnv [get_property VLNV $pin] $port
    connect_bd_intf_net [get_bd_intf_ports $port] $pin
}

# --- addresses (module 24's recipe: movable small segments first,
#     the big fixed RFDC last; range before offset for module refs) ---
assign_bd_address
set core_seg [get_bd_addr_segs -filter {NAME =~ "*llrf_core*"}]
if {[llength $core_seg] != 1} { error "expected one llrf_core segment, got '$core_seg'" }
set_property range 64K $core_seg
set_property offset 0xA0110000 $core_seg
set sa_seg [get_bd_addr_segs -filter {NAME =~ "*snap_adc*"}]
if {[llength $sa_seg] != 1} { error "expected one snap_adc segment, got '$sa_seg'" }
set_property range 64K $sa_seg
set_property offset 0xA0100000 $sa_seg
set sd_seg [get_bd_addr_segs -filter {NAME =~ "*snap_dac*"}]
if {[llength $sd_seg] != 1} { error "expected one snap_dac segment, got '$sd_seg'" }
set_property range 64K $sd_seg
set_property offset 0xA0120000 $sd_seg
set rfdc_seg [get_bd_addr_segs -filter {NAME =~ "*rfdc*"}]
if {[llength $rfdc_seg] != 1} { error "expected one rfdc segment, got '$rfdc_seg'" }
set_property offset 0xA0000000 $rfdc_seg

validate_bd_design
save_bd_design
