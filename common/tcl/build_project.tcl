# Generic non-interactive Vivado project-mode build script, shared by every
# curriculum module and board. It creates (or reopens) a real .xpr project
# under _out/<board>/vivado/ so the result can be inspected or continued in
# the Vivado GUI, then runs synthesis and implementation through bitstream.
#
# Usage:
#   vivado -mode batch -source build_project.tcl -tclargs \
#       <proj_name> <part> <proj_dir> <src_files> <xdc_files> <top> \
#       [board_part] [synth_only|""] [bd_tcl] [ip_tcl]
#
# bd_tcl: optional script that creates one or more block designs
#   (create_bd_design ... save_bd_design). Sourced only when the project
#   has no .bd yet; wrappers are generated automatically afterwards.
# ip_tcl: optional script that creates standalone IP (create_ip ...).
#   Sourced every run - the module's script must guard itself for
#   idempotency (e.g. `if {[llength [get_ips foo]] == 0} { ... }`).

if {$argc < 6} {
    puts "ERROR: build_project.tcl <proj_name> <part> <proj_dir> <src_files> <xdc_files> <top> \[board_part\] \[synth_only\] \[bd_tcl\] \[ip_tcl\]"
    exit 1
}

set proj_name  [lindex $argv 0]
set part       [lindex $argv 1]
set proj_dir   [lindex $argv 2]
set src_files  [lindex $argv 3]
set xdc_files  [lindex $argv 4]
set top        [lindex $argv 5]
set board_part [expr {$argc > 6 ? [lindex $argv 6] : ""}]
set synth_only [expr {$argc > 7 && [lindex $argv 7] eq "synth_only"}]
set bd_tcl     [expr {$argc > 8 ? [lindex $argv 8] : ""}]
set ip_tcl     [expr {$argc > 9 ? [lindex $argv 9] : ""}]

set proj_path [file join $proj_dir $proj_name]

if {[file exists ${proj_path}.xpr]} {
    open_project ${proj_path}.xpr
} else {
    create_project $proj_name $proj_dir -part $part -force
    if {$board_part ne ""} {
        catch {set_property board_part $board_part [current_project]}
    }
}

set_property top $top [current_fileset]

# Re-sync the source list every run so stale/removed files never linger in
# the project (idempotent: safe to run repeatedly as HDL/constraints change).
# Files living under the project dir itself (generated BD wrappers, IP
# output products) are left alone - only user files from the module tree
# get refreshed.
set proj_dir_norm [file normalize $proj_dir]
foreach f [get_files -quiet -of_objects [get_filesets sources_1]] {
    if {[string first $proj_dir_norm [file normalize $f]] != 0} {
        remove_files -fileset sources_1 $f
    }
}
set existing_constrs [get_files -quiet -of_objects [get_filesets constrs_1]]
if {[llength $existing_constrs] > 0} {
    remove_files -fileset constrs_1 $existing_constrs
}

add_files -norecurse -fileset sources_1 $src_files
add_files -norecurse -fileset constrs_1 $xdc_files

# Optional block design: source the creating script once (first build),
# then generate output products + an HDL wrapper the top can instantiate.
if {$bd_tcl ne "" && [llength [get_files -quiet *.bd]] == 0} {
    source $bd_tcl
    foreach bd [get_files -quiet *.bd] {
        generate_target all $bd
        set wrapper [make_wrapper -files $bd -top -force]
        add_files -norecurse -fileset sources_1 $wrapper
    }
}

# Optional standalone IP (script guards its own idempotency).
if {$ip_tcl ne ""} {
    source $ip_tcl
}

set_property top $top [current_fileset]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs [expr {max(1, [exec nproc])}]
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed - see $proj_dir/$proj_name.runs/synth_1/runme.log"
}
puts "Synthesis complete."

if {$synth_only} {
    exit 0
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs [expr {max(1, [exec nproc])}]
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation/bitstream generation failed - see $proj_dir/$proj_name.runs/impl_1/runme.log"
}

puts "Build complete: [get_property DIRECTORY [get_runs impl_1]]"
exit 0
