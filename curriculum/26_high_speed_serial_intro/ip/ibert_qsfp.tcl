# IBERT for the QSFP28 GTY quad (quad 128), 4 lanes at 10.3125 Gb/s from
# the board's 156.25 MHz MGTREFCLK0_128 - the classic 10GbE line-rate /
# refclk pairing. QPLL0 makes the serial clock; the IBERT system clock is
# the same refclk's fabric copy (QUAD128_0), so the design needs no other
# clock input at all.
#
# Sourced every build (IP_TCL hook) - must guard its own idempotency.
if {[llength [get_ips -quiet ibert_qsfp]] == 0} {
    create_ip -name ibert_ultrascale_gty -vendor xilinx.com -library ip \
        -module_name ibert_qsfp
    set_property -dict [list \
        CONFIG.C_PROTOCOL_MAXLINERATE_1 {10.3125} \
        CONFIG.C_PROTOCOL_REFCLK_FREQUENCY_1 {156.25} \
        CONFIG.C_SYSCLOCK_SOURCE_INT {QUAD128_0} \
    ] [get_ips ibert_qsfp]
    # Defaults already select quad 128 / MGTREFCLK0_128 on this part;
    # assert rather than assume (they're load-bearing):
    set refsrc [get_property CONFIG.C_REFCLK_SOURCE_QUAD_1 [get_ips ibert_qsfp]]
    if {$refsrc ne "MGTREFCLK0_128"} {
        error "IBERT refclk source is '$refsrc', expected MGTREFCLK0_128 - check quad mapping"
    }
}
