`timescale 1ns / 1ps

// The module's "real project": a single-intersection traffic light with a
// pedestrian crossing. Green -> Yellow -> Red(+Walk if requested) -> Green,
// with all durations counted in `tick`s (one tick_gen pulse each), so the
// same RTL runs at human speed on hardware and at simulation speed in the
// bench purely by parameter choice.
//
// Behavior:
//  - GREEN holds for GREEN_TICKS, but a latched pedestrian request may cut
//    it short once MIN_GREEN_TICKS have elapsed (drivers get a guaranteed
//    minimum; pedestrians aren't stuck for the full green).
//  - YELLOW always holds YELLOW_TICKS.
//  - RED holds RED_TICKS; `walk` is lit during RED only if the request was
//    latched, and the request clears on entering RED (it was served).
//  - `ped_req` can pulse at any time in any state; it's remembered.
//
// This is a Moore machine (all outputs pure functions of state + the
// latched request), registered timer, two-block style as established in
// the sequence detectors.
module traffic_light #(
    parameter GREEN_TICKS     = 8,
    parameter MIN_GREEN_TICKS = 3,
    parameter YELLOW_TICKS    = 2,
    parameter RED_TICKS       = 6
) (
    input      clk,
    input      rst,
    input      tick,      // one pulse per "second" from tick_gen
    input      ped_req,   // one-cycle pulse (already debounced/edged)
    output     green,
    output     yellow,
    output     red,
    output     walk
);

    localparam [1:0] S_GREEN  = 2'd0,
                     S_YELLOW = 2'd1,
                     S_RED    = 2'd2;

    reg [1:0] state = S_GREEN;
    // `next` gets an initializer too, for a subtle simulation reason: an
    // `always @*` block only runs when something in its sensitivity list
    // CHANGES. With every register above initialized, nothing changes at
    // time zero, the block never fires, and `next` would sit at x -
    // poisoning the timer via (next != state) at the first clock edge.
    // Hardware has no such problem (there is no x); this is purely
    // simulation semantics. SystemVerilog's always_comb exists partly to
    // fix exactly this (it guarantees one execution at time zero).
    reg [1:0] next = S_GREEN;
    reg [$clog2(GREEN_TICKS+1)-1:0] timer = 0;   // counts ticks in current state
    reg       req_latched = 1'b0;
    reg       serving_walk = 1'b0;

    // Latch pedestrian requests until served (cleared on entering RED).
    always @(posedge clk) begin
        if (rst)
            req_latched <= 1'b0;
        else if (ped_req)
            req_latched <= 1'b1;
        else if (tick && state == S_YELLOW && timer == YELLOW_TICKS-1)
            req_latched <= 1'b0;   // about to enter RED: request is being served
    end

    // Remember whether this RED phase owes a walk light.
    always @(posedge clk) begin
        if (rst)
            serving_walk <= 1'b0;
        else if (tick && state == S_YELLOW && timer == YELLOW_TICKS-1)
            serving_walk <= req_latched;
        else if (tick && state == S_RED && timer == RED_TICKS-1)
            serving_walk <= 1'b0;
    end

    // Timer: counts ticks within a state, resets on state change.
    always @(posedge clk) begin
        if (rst)
            timer <= 0;
        else if (tick)
            timer <= (next != state) ? 0 : timer + 1'b1;
    end

    // State register.
    always @(posedge clk) begin
        if (rst) state <= S_GREEN;
        else if (tick) state <= next;
    end

    // Next-state logic. Note everything is guarded by timer values - the
    // FSM only "moves" on ticks (see the state register), so `next` is
    // evaluated in tick-time.
    always @* begin
        next = state;
        case (state)
            S_GREEN:
                if (timer >= GREEN_TICKS-1)
                    next = S_YELLOW;
                else if (req_latched && timer >= MIN_GREEN_TICKS-1)
                    next = S_YELLOW;               // cut short for pedestrian
            S_YELLOW:
                if (timer >= YELLOW_TICKS-1)
                    next = S_RED;
            S_RED:
                if (timer >= RED_TICKS-1)
                    next = S_GREEN;
            default:
                next = S_GREEN;
        endcase
    end

    // Moore outputs.
    assign green  = (state == S_GREEN);
    assign yellow = (state == S_YELLOW);
    assign red    = (state == S_RED);
    assign walk   = (state == S_RED) && serving_walk;

endmodule
