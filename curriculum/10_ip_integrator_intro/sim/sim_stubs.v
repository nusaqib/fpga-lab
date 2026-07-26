`timescale 1ns / 1ps

// Behavioral stand-ins for the generated IP so the top can be simulated
// without running IP generation first - the standard "stub out the IP,
// simulate your own logic" technique. These match the instantiation
// interfaces exactly; their internals are just plausible behavior:
//
//  - clkwiz_sys_wrapper: divide-by-4 (100MHz -> 25MHz) with locked
//    asserting after a few output cycles, like a real MMCM lock delay.
//  - debug_ila: a black hole - a real ILA contributes nothing functional.
//
// These live in sim/ (not hdl/) so hardware builds never see them and use
// the real generated wrapper + ILA instead. If the BD's ports change,
// this stub goes stale - the bench would fail to elaborate, which is the
// desired loud failure.

module clkwiz_sys_wrapper (
    input  clk_in,
    output clk_25m,
    output locked
);
    reg [1:0] div = 0;
    always @(posedge clk_in)
        div <= div + 1'b1;
    assign clk_25m = div[1];

    reg [3:0] lock_cnt = 0;
    assign locked = lock_cnt[3];
    always @(posedge clk_25m)
        if (!locked) lock_cnt <= lock_cnt + 1'b1;
endmodule

module debug_ila (
    input        clk,
    input [25:0] probe0,
    input        probe1
);
endmodule
