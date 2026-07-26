# Out-of-context synthesis: synthesize a module as a standalone block with
# no pin constraints (I/O buffers suppressed), then report what it actually
# used - the honest way to verify "this maps to N DSP48s" for library-style
# blocks whose port count exceeds any board's switches/LEDs.
# Usage: vivado -mode batch -source synth_ooc.tcl -tclargs <part> <top> <outdir> <src_files...>
if {$argc < 4} {
    puts "ERROR: synth_ooc.tcl <part> <top> <outdir> <src...>"
    exit 1
}
set part   [lindex $argv 0]
set top    [lindex $argv 1]
set outdir [lindex $argv 2]
set srcs   [lrange $argv 3 end]

file mkdir $outdir
foreach f $srcs { read_verilog $f }
synth_design -mode out_of_context -top $top -part $part

report_utilization -file $outdir/utilization.rpt
report_timing_summary -file $outdir/timing.rpt

# one-line summary to stdout for the Makefile/user
set luts [expr {[llength [get_cells -hier -quiet -filter {IS_PRIMITIVE && REF_NAME =~ LUT*}]]}]
set ffs  [expr {[llength [get_cells -hier -quiet -filter {IS_PRIMITIVE && REF_NAME =~ FD*}]]}]
set dsps [expr {[llength [get_cells -hier -quiet -filter {IS_PRIMITIVE && REF_NAME =~ DSP*}]]}]
set brams [expr {[llength [get_cells -hier -quiet -filter {IS_PRIMITIVE && (REF_NAME =~ RAMB*)}]]}]
puts "OOC RESULT: top=$top part=$part LUT=$luts FF=$ffs DSP=$dsps BRAM=$brams"
puts "OOC reports: $outdir"
exit 0
