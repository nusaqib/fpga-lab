# Standalone IP: an Integrated Logic Analyzer (ILA) probing the counter.
# The second way to consume Xilinx IP (the first being inside a block
# design) - create_ip produces an .xci that synthesizes alongside the RTL,
# and the RTL instantiates it like any module.
#
# Sourced on EVERY build by common/tcl/build_project.tcl, hence the guard.
#
# ILA in one paragraph: a logic analyzer built from your own BRAM. It
# captures its probe inputs every clock into a ring buffer; when the
# trigger condition you set (from the Vivado GUI, over JTAG, on the live
# board) fires, capture stops and the buffer uploads for waveform viewing.
# It is THE tool for "works in sim, does something else on hardware" - and
# from this module on it's available in every design for the cost of one
# create_ip script and a BRAM.

if {[llength [get_ips -quiet debug_ila]] == 0} {
    create_ip -name ila -vendor xilinx.com -library ip -module_name debug_ila
    set_property -dict [list \
        CONFIG.C_NUM_OF_PROBES  {2} \
        CONFIG.C_PROBE0_WIDTH   {26} \
        CONFIG.C_PROBE1_WIDTH   {1} \
        CONFIG.C_DATA_DEPTH     {1024} \
    ] [get_ips debug_ila]
    generate_target all [get_files -quiet *debug_ila.xci]
}
