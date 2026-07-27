# Module 22 uses no user-selectable pins at all: the RF converter inputs/
# outputs, RF refclks and sysref are dedicated package pins (Vivado bonds
# them from the RFDC IP configuration), and the PS handles UART/SPI over
# MIO. Only device-level bitstream policies live here.
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
