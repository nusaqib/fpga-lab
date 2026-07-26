`timescale 1ns / 1ps

// Drives the traffic light with tick = every clock (TICK_DIV would be 1)
// and small durations, and checks the *sequences*:
//  1) normal cycle: GREEN x8 -> YELLOW x2 -> RED x6 -> GREEN, no walk
//  2) ped request during green after min-green: green cut short at the
//     request tick (>= MIN_GREEN), walk lit for the whole red phase
//  3) ped request in the FIRST green tick: green still holds MIN_GREEN
//  4) exactly one light lit at all times (walk allowed only during red)
module tb_traffic_light;

    localparam GREEN_TICKS = 8, MIN_GREEN = 3, YELLOW_TICKS = 2, RED_TICKS = 6;

    reg  clk = 0, rst, ped_req;
    wire g, y, r, w;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    traffic_light #(
        .GREEN_TICKS(GREEN_TICKS), .MIN_GREEN_TICKS(MIN_GREEN),
        .YELLOW_TICKS(YELLOW_TICKS), .RED_TICKS(RED_TICKS)
    ) dut (
        .clk(clk), .rst(rst), .tick(1'b1), .ped_req(ped_req),
        .green(g), .yellow(y), .red(r), .walk(w)
    );

    // continuous invariant: exactly one of g/y/r; walk only during red
    always @(negedge clk) begin
        if (!rst) begin
            if (g + y + r !== 1) begin
                errors = errors + 1;
                $display("FAIL invariant: g=%b y=%b r=%b", g, y, r);
            end
            if (w && !r) begin
                errors = errors + 1;
                $display("FAIL invariant: walk lit outside red");
            end
        end
    end

    task expect_phase(input exp_g, input exp_y, input exp_r, input exp_w, input [127:0] label);
        begin
            if (g !== exp_g || y !== exp_y || r !== exp_r || w !== exp_w) begin
                errors = errors + 1;
                $display("FAIL %0s: g=%b y=%b r=%b w=%b", label, g, y, r, w);
            end
        end
    endtask

    initial begin
        rst = 1; ped_req = 0;
        @(negedge clk);
        rst = 0;

        // --- 1) one normal cycle, no requests ---
        expect_phase(1,0,0,0, "cycle start green");
        repeat (GREEN_TICKS) @(negedge clk);
        expect_phase(0,1,0,0, "after green -> yellow");
        repeat (YELLOW_TICKS) @(negedge clk);
        expect_phase(0,0,1,0, "after yellow -> red, no walk");
        repeat (RED_TICKS) @(negedge clk);
        expect_phase(1,0,0,0, "red wraps to green");

        // --- 2) request after min-green: cut short ---
        repeat (MIN_GREEN) @(negedge clk);   // timer >= MIN_GREEN-1 satisfied
        ped_req = 1; @(negedge clk); ped_req = 0;
        @(negedge clk);                       // one tick for the FSM to act
        expect_phase(0,1,0,0, "green cut short by request");
        repeat (YELLOW_TICKS) @(negedge clk);
        expect_phase(0,0,1,1, "red WITH walk after request");
        repeat (RED_TICKS) @(negedge clk);
        expect_phase(1,0,0,0, "walk red wraps to green");

        // --- 3) request in first green tick: min-green still honored ---
        // Green re-entered at the edge before the last check; request
        // arrives during its first tick. Green must hold for exactly
        // MIN_GREEN ticks total (timer 0,1,2), then cut to yellow.
        ped_req = 1; @(negedge clk); ped_req = 0;   // tick 1 of green
        @(negedge clk);                              // tick 2
        expect_phase(1,0,0,0, "still green (min-green enforced)");
        @(negedge clk);                              // tick 3 = MIN_GREEN done
        expect_phase(0,1,0,0, "yellow right after min-green");
        repeat (YELLOW_TICKS) @(negedge clk);
        expect_phase(0,0,1,1, "walk served again");

        if (errors == 0) $display("PASS: tb_traffic_light - normal cycle, early-cut, min-green, walk service all correct");
        else              $display("FAIL: tb_traffic_light - %0d error(s)", errors);
        $finish;
    end

endmodule
