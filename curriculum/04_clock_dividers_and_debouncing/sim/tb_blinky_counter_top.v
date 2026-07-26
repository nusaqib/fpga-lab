`timescale 1ns / 1ps

// System check of the demo top with tiny parameters: the blink LED toggles
// at the expected rate, and clean presses advance the counter by exactly
// one each.
module tb_blinky_counter_top;

    localparam BLINK_DIV    = 10;
    localparam STABLE_COUNT = 8;

    reg  clk = 0, btn;
    wire [3:0] led;
    integer errors = 0;
    integer i, toggles = 0;
    reg last_blink;

    always #5 clk = ~clk;

    blinky_counter_top #(
        .BLINK_DIV    (BLINK_DIV),
        .STABLE_COUNT (STABLE_COUNT)
    ) dut (.clk(clk), .btn(btn), .led(led));

    task clean_press;
        begin
            btn = 1;
            repeat (STABLE_COUNT * 2 + 4) @(negedge clk);
            btn = 0;
            repeat (STABLE_COUNT * 2 + 4) @(negedge clk);
        end
    endtask

    initial begin
        btn = 0;
        repeat (4) @(negedge clk);

        // Blink rate: over 10*BLINK_DIV cycles expect ~10 toggles.
        last_blink = led[3];
        for (i = 0; i < 10*BLINK_DIV; i = i + 1) begin
            @(negedge clk);
            if (led[3] !== last_blink) begin
                toggles = toggles + 1;
                last_blink = led[3];
            end
        end
        if (toggles < 9 || toggles > 11) begin
            errors = errors + 1;
            $display("FAIL: %0d blink toggles in %0d cycles, expected ~10", toggles, 10*BLINK_DIV);
        end

        // Three clean presses -> counter reads exactly 3.
        if (led[2:0] !== 3'd0) begin errors = errors + 1; $display("FAIL: counter nonzero before presses: %0d", led[2:0]); end
        clean_press; clean_press; clean_press;
        if (led[2:0] !== 3'd3) begin errors = errors + 1; $display("FAIL: counter=%0d after 3 presses, expected 3", led[2:0]); end

        if (errors == 0) $display("PASS: tb_blinky_counter_top - blink rate correct, 3 presses counted as 3");
        else              $display("FAIL: tb_blinky_counter_top - %0d error(s)", errors);
        $finish;
    end

endmodule
