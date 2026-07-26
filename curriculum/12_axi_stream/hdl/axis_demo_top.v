`timescale 1ns / 1ps

// Shell: button -> debounce -> edge_detect -> one packet per press into
// the BD's stream pipeline; LEDs show the capture block's beat counter
// (jumps by 16 per press once the packet drains through).
module axis_demo_top #(
    parameter STABLE_COUNT = 1_000_000
) (
    input        clk,
    input        btn,
    output [3:0] led
);

    wire btn_clean, start_pulse;
    debounce #(.STABLE_COUNT(STABLE_COUNT)) u_db (
        .clk(clk), .rst(1'b0), .noisy_in(btn), .clean_out(btn_clean)
    );
    edge_detect u_edge (
        .clk(clk), .level_in(btn_clean), .pulse_out(start_pulse)
    );

    axis_pipe_sys_wrapper u_bd (
        .clk    (clk),
        .resetn (1'b1),
        .start  (start_pulse),
        .led    (led)
    );

endmodule
