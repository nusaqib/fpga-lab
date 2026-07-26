# Export a hardware platform (.xsa) from an already-built project - the
# handoff artifact from Vivado to Vitis (Tier 5+). Includes the bitstream.
# Usage: vivado -mode batch -source export_xsa.tcl -tclargs <xpr> <xsa_out>
if {$argc < 2} {
    puts "ERROR: export_xsa.tcl <xpr> <xsa_out>"
    exit 1
}
set xpr [lindex $argv 0]
set xsa [lindex $argv 1]

open_project $xpr
write_hw_platform -fixed -include_bit -force $xsa
puts "XSA written: $xsa"
exit 0
