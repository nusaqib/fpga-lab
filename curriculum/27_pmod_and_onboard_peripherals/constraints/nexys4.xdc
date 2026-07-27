## Pins verbatim from boards/nexys4/xdc/Nexys4-Master.xdc (vendored,
## Digilent official - note: the ORIGINAL Nexys4; the Nexys4-DDR/A7 has
## a completely different LED pinout, a from-memory trap caught during
## this module's authoring): 100MHz clock, ADT7420 I2C, USB-UART, LEDs.
set_property PACKAGE_PIN E3 [get_ports clk100]
set_property IOSTANDARD LVCMOS33 [get_ports clk100]
create_clock -period 10.000 -name sys_clk [get_ports clk100]

## Temp sensor (TMP_SCL / TMP_SDA) - open-drain, on-board pull-ups
set_property PACKAGE_PIN F16 [get_ports tmp_scl]
set_property IOSTANDARD LVCMOS33 [get_ports tmp_scl]
set_property PACKAGE_PIN G16 [get_ports tmp_sda]
set_property IOSTANDARD LVCMOS33 [get_ports tmp_sda]

## USB-UART: UART_RXD_OUT (FPGA transmits to host)
set_property PACKAGE_PIN D4 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

## LEDs
set_property PACKAGE_PIN T8 [get_ports {led[0]}]
set_property PACKAGE_PIN V9 [get_ports {led[1]}]
set_property PACKAGE_PIN R8 [get_ports {led[2]}]
set_property PACKAGE_PIN T6 [get_ports {led[3]}]
set_property PACKAGE_PIN T5 [get_ports {led[4]}]
set_property PACKAGE_PIN T4 [get_ports {led[5]}]
set_property PACKAGE_PIN U7 [get_ports {led[6]}]
set_property PACKAGE_PIN U6 [get_ports {led[7]}]
set_property PACKAGE_PIN V4 [get_ports {led[8]}]
set_property PACKAGE_PIN U3 [get_ports {led[9]}]
set_property PACKAGE_PIN V1 [get_ports {led[10]}]
set_property PACKAGE_PIN R1 [get_ports {led[11]}]
set_property PACKAGE_PIN P5 [get_ports {led[12]}]
set_property PACKAGE_PIN U1 [get_ports {led[13]}]
set_property PACKAGE_PIN R2 [get_ports {led[14]}]
set_property PACKAGE_PIN P2 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports uart_txd]
## I2C is kHz-slow and re-synchronized by the quarter-bit sampler
set_false_path -from [get_ports tmp_sda]
set_false_path -from [get_ports tmp_scl]
set_false_path -to [get_ports tmp_sda]
set_false_path -to [get_ports tmp_scl]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
