`timescale 1ns / 1ps

// Top for the first IP-integrator module: instantiates the generated BD
// wrapper (clkwiz_sys_wrapper - a module that exists only after the first
// build generates it from bd/clkwiz_sys.tcl), runs a counter in the new
// 25MHz domain, and hangs an ILA off the counter for live on-hardware
// inspection.
//
//   led[2:0] = counter MSBs (three blink rates, ~0.4/0.8/1.5s periods)
//   led[3]   = MMCM locked
module ipi_blinky_top (
    input        clk,      // 100MHz board oscillator
    output [3:0] led
);

    wire clk_25m, locked;

    clkwiz_sys_wrapper u_bd (
        .clk_in  (clk),
        .clk_25m (clk_25m),
        .locked  (locked)
    );

    // Counter in the DERIVED clock domain. Held in reset until the MMCM
    // locks - clk_25m isn't trustworthy before `locked`.
    reg [25:0] counter = 0;
    always @(posedge clk_25m) begin
        if (!locked) counter <= 0;
        else         counter <= counter + 1'b1;
    end

    assign led[2:0] = counter[25:23];
    assign led[3]   = locked;

    // ILA on the 25MHz domain: probe the whole counter + locked. After
    // programming, open Vivado's Hardware Manager - the ILA appears next
    // to the device; set a trigger (e.g. counter[22] rising) and watch
    // real on-chip values. See the README walkthrough.
    debug_ila u_ila (
        .clk    (clk_25m),
        .probe0 (counter),
        .probe1 (locked)
    );

endmodule
