`timescale 1ns / 1ps

// Moore FSM detecting the serial pattern "1011" (overlapping allowed).
// Moore = outputs depend on STATE ONLY, so `found` is registered-clean and
// asserts the cycle AFTER the final '1' arrives - one cycle later than the
// Mealy version next door, in exchange for a glitch-free output.
//
// Style notes this module exists to establish:
//  - localparam state encoding (values are arbitrary; synthesis usually
//    re-encodes anyway - see README on one-hot vs binary),
//  - two always blocks: sequential state register + combinational
//    next-state logic, with a default assignment up top so no branch can
//    infer a latch,
//  - a full case with default recovering to IDLE.
module sequence_detector_moore (
    input      clk,
    input      rst,
    input      din,
    output     found
);

    localparam [2:0] S_IDLE  = 3'd0,  // nothing useful seen
                     S_1     = 3'd1,  // seen 1
                     S_10    = 3'd2,  // seen 10
                     S_101   = 3'd3,  // seen 101
                     S_1011  = 3'd4;  // seen 1011 <- output state

    reg [2:0] state, next;

    // state register
    always @(posedge clk) begin
        if (rst) state <= S_IDLE;
        else     state <= next;
    end

    // next-state logic (combinational; default first, then overrides)
    always @* begin
        next = S_IDLE;
        case (state)
            S_IDLE: next = din ? S_1    : S_IDLE;
            S_1:    next = din ? S_1    : S_10;
            S_10:   next = din ? S_101  : S_IDLE;
            S_101:  next = din ? S_1011 : S_10;   // "10" suffix reusable
            S_1011: next = din ? S_1    : S_10;   // overlap: "...1011" ends in "1"/"10"
            default: next = S_IDLE;
        endcase
    end

    // Moore output: a pure function of state
    assign found = (state == S_1011);

endmodule
