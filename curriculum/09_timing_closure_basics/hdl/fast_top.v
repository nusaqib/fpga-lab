`timescale 1ns / 1ps

// The passing build: same math as slow_top but through the pipelined
// chain, plus the multicycle-path example alongside (its constraint lives
// in the XDC). LEDs fold both results together so neither is pruned.
module fast_top (
    input        clk,
    input  [3:0] sw,
    output [3:0] led
);

    reg [31:0] counter = 0;
    always @(posedge clk)
        counter <= counter + 1'b1;

    wire [31:0] x = counter ^ {8{sw}};

    wire [31:0] r_pipe, r_mcp;
    mult_chain_pipelined u_pipe (.clk(clk), .x(x), .result(r_pipe));
    mcp_example          u_mcp  (.clk(clk), .x(x), .result(r_mcp));

    wire [31:0] r = r_pipe ^ r_mcp;

    assign led[0] = ^r[7:0];
    assign led[1] = ^r[15:8];
    assign led[2] = ^r[23:16];
    assign led[3] = ^r[31:24];

endmodule
