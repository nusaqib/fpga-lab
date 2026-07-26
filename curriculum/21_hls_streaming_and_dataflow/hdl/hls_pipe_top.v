`timescale 1ns / 1ps

// Same shell as module 12: button -> debounce -> edge_detect -> one
// 16-beat packet per press. The difference is inside the BD: the middle
// of the pipeline is now a generated HLS IP, and the decimation shows up
// on the LEDs - the beat counter jumps by 8 per press, not 16.
module hls_pipe_top #(
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

    hls_pipe_sys_wrapper u_bd (
        .clk    (clk),
        .resetn (1'b1),
        .start  (start_pulse),
        .led    (led)
    );

endmodule
