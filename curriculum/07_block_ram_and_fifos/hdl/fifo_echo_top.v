`timescale 1ns / 1ps

// Hardware demo: a FIFO you can watch working. Each button press pushes
// the current switch pattern into the FIFO; a slow ~0.5Hz consumer pops
// one entry onto the LEDs every 2 seconds. Punch in several patterns
// quickly, then watch them come back out in order, at the consumer's
// pace - producer and consumer decoupled by the queue between them, which
// is the entire reason FIFOs exist.
module fifo_echo_top #(
    parameter POP_DIV      = 200_000_000,  // one pop every 2s at 100MHz
    parameter STABLE_COUNT = 1_000_000     // 10ms debounce
) (
    input        clk,
    input        btn,
    input  [3:0] sw,
    output [3:0] led
);

    // producer: debounced button press -> push switches
    wire btn_clean, push_pulse;
    debounce #(.STABLE_COUNT(STABLE_COUNT)) u_db (
        .clk(clk), .rst(1'b0), .noisy_in(btn), .clean_out(btn_clean)
    );
    edge_detect u_edge (
        .clk(clk), .level_in(btn_clean), .pulse_out(push_pulse)
    );

    // consumer: slow tick -> pop onto LEDs
    wire pop_tick;
    tick_gen #(.DIV(POP_DIV)) u_tick (
        .clk(clk), .rst(1'b0), .tick(pop_tick)
    );

    wire [3:0] fifo_out;
    wire       full, empty;
    reg  [3:0] led_r = 4'b0;

    fifo_sync #(.WIDTH(4), .DEPTH(16)) u_fifo (
        .clk   (clk),
        .rst   (1'b0),
        .wr_en (push_pulse),
        .wdata (sw),
        .rd_en (pop_tick),
        .rdata (fifo_out),
        .full  (full),
        .empty (empty),
        .count ()
    );

    // Register the popped value one cycle after an accepted pop (the
    // FIFO's read latency), and hold it until the next one.
    reg pop_accepted = 1'b0;
    always @(posedge clk) begin
        pop_accepted <= pop_tick && !empty;
        if (pop_accepted)
            led_r <= fifo_out;
    end

    assign led = led_r;

endmodule
