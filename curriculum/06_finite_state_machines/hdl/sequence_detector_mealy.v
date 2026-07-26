`timescale 1ns / 1ps

// Mealy FSM detecting the same "1011" pattern (overlapping allowed).
// Mealy = outputs depend on STATE AND INPUT, so `found` fires in the SAME
// cycle the final '1' arrives - one cycle earlier than the Moore version,
// in exchange for an output that is combinational on `din` (it can glitch
// if din glitches, and it eats into downstream setup time).
//
// Note it needs one fewer state than the Moore machine: the "success"
// isn't a state you sit in, it's a transition you announce on the way
// through.
module sequence_detector_mealy (
    input      clk,
    input      rst,
    input      din,
    output reg found
);

    localparam [1:0] S_IDLE = 2'd0,
                     S_1    = 2'd1,
                     S_10   = 2'd2,
                     S_101  = 2'd3;

    reg [1:0] state, next;

    always @(posedge clk) begin
        if (rst) state <= S_IDLE;
        else     state <= next;
    end

    always @* begin
        next  = S_IDLE;
        found = 1'b0;
        case (state)
            S_IDLE: next = din ? S_1   : S_IDLE;
            S_1:    next = din ? S_1   : S_10;
            S_10:   next = din ? S_101 : S_IDLE;
            S_101: begin
                if (din) begin
                    found = 1'b1;     // fires ON the final '1', this cycle
                    next  = S_1;      // overlap: trailing "1" reusable
                end else begin
                    next = S_10;
                end
            end
            default: next = S_IDLE;
        endcase
    end

endmodule
