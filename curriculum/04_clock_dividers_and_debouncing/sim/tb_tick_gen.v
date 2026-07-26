`timescale 1ns / 1ps

// Checks tick_gen with a small DIV: exactly one tick every DIV cycles, one
// cycle wide, at the right position. Parameter overridden at instantiation
// - simulating the default hundred-million-cycle second would be pointless.
module tb_tick_gen;

    localparam DIV = 7;
    localparam CYCLES = 100;

    reg  clk = 0, rst;
    wire tick;
    integer errors = 0;
    integer i, ticks_seen = 0, last_tick_cycle = -1;

    always #5 clk = ~clk;

    tick_gen #(.DIV(DIV)) dut (.clk(clk), .rst(rst), .tick(tick));

    initial begin
        rst = 1;
        @(negedge clk);
        rst = 0;

        for (i = 0; i < CYCLES; i = i + 1) begin
            @(negedge clk);
            if (tick) begin
                ticks_seen = ticks_seen + 1;
                if (last_tick_cycle >= 0 && (i - last_tick_cycle) != DIV) begin
                    errors = errors + 1;
                    $display("FAIL: ticks %0d cycles apart, expected %0d", i - last_tick_cycle, DIV);
                end
                last_tick_cycle = i;
            end
        end

        // 100 cycles / DIV=7 -> should have seen 14 ticks, +-1 for phase.
        if (ticks_seen < CYCLES/DIV || ticks_seen > CYCLES/DIV + 1) begin
            errors = errors + 1;
            $display("FAIL: saw %0d ticks in %0d cycles, expected ~%0d", ticks_seen, CYCLES, CYCLES/DIV);
        end

        if (errors == 0) $display("PASS: tb_tick_gen - %0d ticks, every %0d cycles, one cycle wide", ticks_seen, DIV);
        else              $display("FAIL: tb_tick_gen - %0d error(s)", errors);
        $finish;
    end

endmodule
