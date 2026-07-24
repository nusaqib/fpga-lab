# Program a bitstream onto whatever hardware target is attached via
# JTAG/hw_server. Usage: vivado -mode batch -source program.tcl -tclargs <bitfile>
if {$argc < 1} {
    puts "ERROR: program.tcl <bitfile>"
    exit 1
}
set bitfile [lindex $argv 0]

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set device [lindex [get_hw_devices] 0]
if {$device eq ""} {
    error "No hw_device found - check USB/JTAG connection and power"
}
current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set_property PROGRAM.FILE $bitfile $device
program_hw_devices $device

puts "Programmed $device with $bitfile"
close_hw_manager
exit 0
