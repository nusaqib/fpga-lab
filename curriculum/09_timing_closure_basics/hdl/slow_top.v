`timescale 1ns / 1ps

// The deliberately-failing build. A free-running counter (XORed with the
// switches so synthesis can't constant-fold anything) feeds the
// unpipelined triple-multiply; LEDs show XOR-folded slices of the result
// so nothing gets optimized away. Build this, then read the negative
// slack in the timing summary - see the module README for exactly where
// to look.
module slow_top (
    input        clk,
    input  [3:0] sw,
    output [3:0] led
);

    reg [31:0] counter = 0;
    always @(posedge clk)
        counter <= counter + 1'b1;

    wire [31:0] x = counter ^ {8{sw}};

    wire [31:0] result;
    mult_chain_slow u_slow (.clk(clk), .x(x), .result(result));

    assign led[0] = ^result[7:0];
    assign led[1] = ^result[15:8];
    assign led[2] = ^result[23:16];
    assign led[3] = ^result[31:24];

endmodule
