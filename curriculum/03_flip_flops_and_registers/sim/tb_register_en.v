`timescale 1ns / 1ps

// Randomized rather than exhaustive - a register's input space across time
// doesn't enumerate the way a combinational truth table does, so instead:
// drive random d/en/rst for a few hundred cycles and check the output
// against a behavioral reference model every cycle. This
// "scoreboard/reference model" shape is the standard next step after
// module 01/02's exhaustive loops.
module tb_register_en;

    localparam WIDTH = 4;
    localparam CYCLES = 300;

    reg              clk = 0, rst, en;
    reg  [WIDTH-1:0] d;
    wire [WIDTH-1:0] q;
    reg  [WIDTH-1:0] model_q;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    register_en #(.WIDTH(WIDTH)) dut (.clk(clk), .rst(rst), .en(en), .d(d), .q(q));

    initial begin
        // Known start.
        rst = 1; en = 0; d = 0; model_q = 0;
        @(negedge clk);
        rst = 0;

        for (i = 0; i < CYCLES; i = i + 1) begin
            // New random stimulus, applied at negedge (stable before the
            // posedge sample).
            d   = $random;
            en  = $random;
            rst = ($random % 8 == 0);   // occasional reset

            // Update the reference model with the same semantics the DUT
            // is supposed to have...
            if (rst)     model_q = 0;
            else if (en) model_q = d;

            @(negedge clk);   // ...then let the DUT take its posedge

            if (q !== model_q) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: rst=%b en=%b d=%h q=%h model=%h", i, rst, en, d, q, model_q);
            end
        end

        if (errors == 0) $display("PASS: tb_register_en - %0d random cycles match reference model", CYCLES);
        else              $display("FAIL: tb_register_en - %0d error(s)", errors);
        $finish;
    end

endmodule
