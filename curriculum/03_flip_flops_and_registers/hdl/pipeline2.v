`timescale 1ns / 1ps

// Two flops back to back: q ends up being d delayed by exactly two clock
// edges. Exists to make the non-blocking (`<=`) lesson concrete - see
// sim/tb_pipeline2.v, which proves the 2-cycle delay, and the module README
// for what would go wrong if these were blocking (`=`) assignments instead.
//
// The key mental model: every `<=` in the design samples its right-hand
// side using values from *before* the clock edge, then all left-hand sides
// update together. Order of the two statements below therefore doesn't
// matter - swap them and the behavior is identical. With blocking `=` it
// would matter, and one order would silently collapse the two stages into
// one.
module pipeline2 (
    input      clk,
    input      d,
    output reg q
);

    reg stage1;

    always @(posedge clk) begin
        stage1 <= d;
        q      <= stage1;
    end

endmodule
