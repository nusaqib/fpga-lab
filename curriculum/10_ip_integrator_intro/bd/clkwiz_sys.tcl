# Block design: a Clocking Wizard wrapped in the smallest possible BD.
# 100MHz board clock in -> 25MHz fabric clock + locked flag out.
#
# This file IS the block design as far as git is concerned - the .bd it
# creates is a build artifact. That's the repo's BD philosophy: never
# commit generated files; commit the script that creates them. (For a
# design drawn interactively in the GUI, `write_bd_tcl` exports exactly
# this kind of script - draw once, export, commit the export.)
#
# Sourced by common/tcl/build_project.tcl on the first build of a project
# that has no .bd yet; the wrapper generation happens there too.

create_bd_design "clkwiz_sys"

# The Clocking Wizard drives an MMCM (mixed-mode clock manager) - the
# proper answer to module 04's "how do I actually get a different clock
# frequency" question. Derived clocks from an MMCM live on the dedicated
# clock network and get their timing constraints generated automatically.
set clkwiz [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz_0]
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ                {100.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ  {25.000} \
    CONFIG.USE_LOCKED                  {true} \
    CONFIG.USE_RESET                   {false} \
] $clkwiz

# External ports: input clock, output clock, locked status.
create_bd_port -dir I -type clk -freq_hz 100000000 clk_in
connect_bd_net [get_bd_ports clk_in] [get_bd_pins clk_wiz_0/clk_in1]

create_bd_port -dir O -type clk clk_25m
connect_bd_net [get_bd_ports clk_25m] [get_bd_pins clk_wiz_0/clk_out1]

create_bd_port -dir O locked
connect_bd_net [get_bd_ports locked] [get_bd_pins clk_wiz_0/locked]

validate_bd_design
save_bd_design
