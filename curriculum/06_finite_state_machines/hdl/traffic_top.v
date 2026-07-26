`timescale 1ns / 1ps

// Hardware demo: the traffic light at human speed. One tick per second;
// green 8s (min 3s), yellow 2s, red 6s. The button is a pedestrian
// request through the full module-04 input stack.
//
//   led[0] = green   led[1] = yellow   led[2] = red   led[3] = walk
//
// Press the button mid-green: if 3s of green have elapsed it goes yellow
// almost immediately, and the walk LED lights for the following red.
module traffic_top #(
    parameter TICK_DIV     = 100_000_000,  // 1s at 100MHz
    parameter STABLE_COUNT = 1_000_000     // 10ms debounce
) (
    input        clk,
    input        btn,
    output [3:0] led
);

    wire tick;
    tick_gen #(.DIV(TICK_DIV)) u_tick (
        .clk(clk), .rst(1'b0), .tick(tick)
    );

    wire btn_clean, ped_pulse;
    debounce #(.STABLE_COUNT(STABLE_COUNT)) u_db (
        .clk(clk), .rst(1'b0), .noisy_in(btn), .clean_out(btn_clean)
    );
    edge_detect u_edge (
        .clk(clk), .level_in(btn_clean), .pulse_out(ped_pulse)
    );

    traffic_light #(
        .GREEN_TICKS     (8),
        .MIN_GREEN_TICKS (3),
        .YELLOW_TICKS    (2),
        .RED_TICKS       (6)
    ) u_fsm (
        .clk     (clk),
        .rst     (1'b0),
        .tick    (tick),
        .ped_req (ped_pulse),
        .green   (led[0]),
        .yellow  (led[1]),
        .red     (led[2]),
        .walk    (led[3])
    );

endmodule
