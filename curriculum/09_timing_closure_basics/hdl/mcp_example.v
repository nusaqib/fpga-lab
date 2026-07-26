`timescale 1ns / 1ps

// The legitimate multicycle path: a result register that is only ENABLED
// every 4th cycle, fed by deliberately-slow logic (the same triple-mult
// cloud as mult_chain_slow). Because the capture flop only samples when
// en_div4 fires, the combinational cloud genuinely has 4 clock periods to
// settle - telling the tools that via set_multicycle_path (see the
// constraints file) is stating a fact, not waiving a check.
//
// Contrast with set_false_path, which says "never check this at all" and
// is only honest for genuinely asynchronous crossings (module 08's Gray
// pointers) or static configuration signals. Using false_path where
// multicycle_path is the truth means nothing ever verifies the 4-cycle
// budget actually suffices.
module mcp_example (
    input             clk,
    input      [31:0] x,
    output reg [31:0] result = 0
);

    // enable once every 4 cycles
    reg [1:0] div = 0;
    always @(posedge clk)
        div <= div + 1'b1;
    wire en_div4 = (div == 2'b11);

    // source register, also enabled every 4 cycles - so the cloud's input
    // holds still for the full 4-cycle budget (this is what makes the MCP
    // claim true; a source that changed every cycle would break it).
    reg [31:0] x_r = 0;
    always @(posedge clk)
        if (en_div4) x_r <= x;

    (* keep = "true" *) wire [31:0] p1 = x_r * 32'h9E3779B1;
    (* keep = "true" *) wire [31:0] p2 = p1  * 32'h85EBCA77;
    wire [31:0] p3 = p2  * 32'hC2B2AE3D;

    always @(posedge clk)
        if (en_div4) result <= p3;

endmodule
