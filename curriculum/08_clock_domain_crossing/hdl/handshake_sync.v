`timescale 1ns / 1ps

// Multi-bit CDC via 4-phase request/acknowledge handshake. The rule it
// exists to satisfy: NEVER pass a multi-bit value through per-bit
// synchronizers - each bit resolves independently, so a value changing
// from 0111 to 1000 can be seen as anything in between for a cycle.
// Instead: (1) source freezes the data in a register, (2) raises req,
// (3) req crosses via sync2 (one bit - safe), (4) destination samples the
// frozen data - guaranteed stable, it hasn't moved since before req rose -
// and raises ack, (5) ack crosses back, source drops req, waits for ack
// to drop, done. Slow (several cycles of both clocks per word) but
// bulletproof, and the right tool for low-rate config/status values.
// For throughput, use the async FIFO instead.
module handshake_sync #(
    parameter WIDTH = 8
) (
    input                  src_clk,
    input                  src_valid,   // pulse: send src_data now
    input  [WIDTH-1:0]     src_data,
    output                 src_busy,    // transfer in flight, don't send
    input                  dst_clk,
    output reg             dst_valid,   // one-cycle pulse: dst_data fresh
    output reg [WIDTH-1:0] dst_data
);

    // ---- source domain ----
    reg              req = 1'b0;
    reg [WIDTH-1:0]  data_frozen = {WIDTH{1'b0}};
    wire             ack_s;

    assign src_busy = req | ack_s;   // busy until the full 4-phase completes

    always @(posedge src_clk) begin
        if (src_valid && !src_busy) begin
            data_frozen <= src_data;   // freeze FIRST...
            req         <= 1'b1;       // ...then announce (same edge is fine:
                                       // req takes 2+ dst clocks to arrive)
        end else if (req && ack_s) begin
            req <= 1'b0;               // dst has it; retire the request
        end
    end

    // ---- destination domain state (declared before the crossings use it) ----
    reg ack = 1'b0;
    reg req_s_last = 1'b0;

    // ---- crossings (one bit each way) ----
    wire req_s;
    sync2 u_req  (.clk(dst_clk), .async_in(req),   .sync_out(req_s));
    sync2 u_ack  (.clk(src_clk), .async_in(ack),   .sync_out(ack_s));

    always @(posedge dst_clk) begin
        req_s_last <= req_s;
        dst_valid  <= 1'b0;
        if (req_s && !req_s_last) begin
            dst_data  <= data_frozen;  // stable by construction
            dst_valid <= 1'b1;
            ack       <= 1'b1;
        end else if (!req_s) begin
            ack <= 1'b0;               // source dropped req: close the phase
        end
    end

endmodule
