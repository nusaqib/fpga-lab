# Module 30 - the capstone: a complete RISC-V SoC where EVERYTHING is
# fabric. MicroBlaze-V (AMD's RV32 soft core) + 128KB of BRAM as main
# memory + AXI UART/GPIO/timer/interrupt-controller, on the Nexys4 -
# the board that spent 29 modules being "the one without a processor".
# It had one all along; we just hadn't built it yet.
#
# The journey's full circle: module 00 wired switches to LEDs with no
# clock; module 30 boots C code on a CPU that is itself just more LUTs,
# and wires switches to LEDs with a shell command.

create_bd_design "riscv_soc"

# 100 MHz straight from the board oscillator; CPU_RESET button (active
# low) as the system reset, exactly like a real little computer.
set clk [create_bd_port -dir I -type clk -freq_hz 100000000 clk100]
set rstn [create_bd_port -dir I -type rst cpu_resetn]
set_property CONFIG.POLARITY ACTIVE_LOW $rstn

set mbv [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze_riscv microblaze_riscv_0]
apply_bd_automation -rule xilinx.com:bd_rule:microblaze_riscv -config { \
    local_mem "128KB" ecc "None" cache "None" debug_module "Debug Only" \
    axi_periph "Enabled" axi_intc "1" clk "/clk100 (100 MHz)" } $mbv

# wire the button into whatever reset block the automation created
set rst_cell [get_bd_cells -quiet -filter {VLNV =~ "*proc_sys_reset*"}]
if {[llength $rst_cell] == 0} { error "automation created no proc_sys_reset" }
connect_bd_net [get_bd_ports cpu_resetn] \
    [get_bd_pins -of_objects $rst_cell -filter {NAME == "ext_reset_in"}]

# --- peripherals ---
set uart [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite axi_uartlite_0]
set_property -dict [list CONFIG.C_BAUDRATE {115200}] $uart
set gpio_led [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_led]
set_property -dict [list CONFIG.C_GPIO_WIDTH {16} CONFIG.C_ALL_OUTPUTS {1}] $gpio_led
set gpio_sw [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio axi_gpio_sw]
set_property -dict [list CONFIG.C_GPIO_WIDTH {16} CONFIG.C_ALL_INPUTS {1}] $gpio_sw
set tmr [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer axi_timer_0]

foreach periph {axi_uartlite_0 axi_gpio_led axi_gpio_sw axi_timer_0} {
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config \
        [list Clk_master {/clk100 (100 MHz)} Clk_slave {Auto} Clk_xbar {Auto} \
              Master "/microblaze_riscv_0 (Periph)" Slave "/$periph/S_AXI" \
              ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}]
}

# --- interrupts: timer + uart into the intc the automation created ---
set intc [get_bd_cells -quiet -filter {VLNV =~ "*axi_intc*"}]
if {[llength $intc] != 1} { error "expected one axi_intc, got '$intc'" }
set cc [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat intr_concat]
set_property CONFIG.NUM_PORTS {2} $cc
connect_bd_net [get_bd_pins axi_timer_0/interrupt]    [get_bd_pins intr_concat/In0]
connect_bd_net [get_bd_pins axi_uartlite_0/interrupt] [get_bd_pins intr_concat/In1]
# the automation may have pre-wired a concat; replace its intr net if so
set intr_pin [get_bd_pins -of_objects $intc -filter {NAME == "intr"}]
foreach n [get_bd_nets -quiet -of_objects $intr_pin] { delete_bd_objs $n }
connect_bd_net [get_bd_pins intr_concat/dout] $intr_pin

# --- pins out ---
create_bd_port -dir O -from 15 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins axi_gpio_led/gpio_io_o]
create_bd_port -dir I -from 15 -to 0 sw
connect_bd_net [get_bd_ports sw] [get_bd_pins axi_gpio_sw/gpio_io_i]
create_bd_port -dir I uart_rxd
connect_bd_net [get_bd_ports uart_rxd] [get_bd_pins axi_uartlite_0/rx]
create_bd_port -dir O uart_txd
connect_bd_net [get_bd_ports uart_txd] [get_bd_pins axi_uartlite_0/tx]

assign_bd_address
validate_bd_design
save_bd_design
