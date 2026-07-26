`timescale 1ns / 1ps

// Reference-model bench (the module 03 pattern): random en/up/load/d/rst
// every cycle, behavioral model updated with the intended semantics,
// compared every cycle. The priority order rst > load > en is exercised
// by construction since the random stimulus regularly asserts several at
// once.
module tb_counter_updown;

    localparam WIDTH = 4;
    localparam CYCLES = 500;

    reg              clk = 0, rst, en, up, load;
    reg  [WIDTH-1:0] d;
    wire [WIDTH-1:0] count;
    reg  [WIDTH-1:0] model;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    counter_updown #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst(rst), .en(en), .up(up), .load(load), .d(d), .count(count)
    );

    initial begin
        rst = 1; en = 0; up = 1; load = 0; d = 0; model = 0;
        @(negedge clk);
        rst = 0;

        for (i = 0; i < CYCLES; i = i + 1) begin
            en   = $random;
            up   = $random;
            load = ($random % 4 == 0);
            rst  = ($random % 16 == 0);
            d    = $random;

            if (rst)       model = 0;
            else if (load) model = d;
            else if (en)   model = up ? model + 1'b1 : model - 1'b1;

            @(negedge clk);

            if (count !== model) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: rst=%b load=%b en=%b up=%b d=%h count=%h model=%h",
                         i, rst, load, en, up, d, count, model);
            end
        end

        if (errors == 0) $display("PASS: tb_counter_updown - %0d random cycles match reference model", CYCLES);
        else              $display("FAIL: tb_counter_updown - %0d error(s)", errors);
        $finish;
    end

endmodule
