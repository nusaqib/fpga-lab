# Generic Vitis Unified IDE (xsct) application build script, shared by every
# Zynq/RFSoC software module. Creates a platform + domain + app component from
# an exported .xsa, adds the module's C/C++ sources, and builds.
#
# Usage: xsct build_app.tcl <workspace_dir> <app_name> <xsa_path> <src_files> [proc_name]
#   proc_name defaults to psu_cortexa53_0 (RFSoC4x2); pass ps7_cortexa9_0 for
#   BlackBoard's Zynq-7000.
#
# NOTE: this is the generic first-cut used by curriculum/07_zynq_ps_bringup
# onward; refined per-module as embedded-software content grows.

if {$argc < 4} {
    puts "ERROR: build_app.tcl <workspace_dir> <app_name> <xsa_path> <src_files> \[proc_name\]"
    exit 1
}

set ws        [lindex $argv 0]
set app_name  [lindex $argv 1]
set xsa       [lindex $argv 2]
set src       [lindex $argv 3]
set proc_name [expr {$argc > 4 ? [lindex $argv 4] : "psu_cortexa53_0"}]

setws $ws

set platform_name "${app_name}_platform"
if {[lsearch [platform list] $platform_name] < 0} {
    platform create -name $platform_name -hw $xsa -proc $proc_name -os standalone -out $ws
}
platform active $platform_name

if {[lsearch [app list] $app_name] < 0} {
    app create -name $app_name -platform $platform_name -domain standalone_domain -template {Empty Application(C)}
}

foreach f $src {
    importsources -name $app_name -path $f
}

app build -name $app_name
puts "Vitis build complete: $ws/$app_name"
exit 0
