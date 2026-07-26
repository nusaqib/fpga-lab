`timescale 1ns / 1ps

// A one-stage AXI-Stream processing block (multiply every sample by a
// constant) with a REGISTERED output and a SKID BUFFER - the single most
// important structure in stream design.
//
// The problem it solves: for timing you want both your output signals AND
// your upstream-facing tready to come from registers. But a registered
// tready is one cycle stale - when downstream stalls, you find out a
// cycle late, and by then upstream (seeing your stale tready=1) has
// already launched one more beat at you. The skid buffer is a one-beat
// side register that catches exactly that in-flight beat, so nothing is
// ever dropped and nothing upstream ever needs to rewind.
//
// Rules encoded below, worth internalizing as a checklist:
//  - accept a beat whenever s_tready is high and s_tvalid is high,
//  - s_tready (registered) goes low only when BOTH the main output reg
//    and the skid reg are occupied,
//  - drain the skid first when downstream frees up (order preserved).
module axis_scaler #(
    parameter WIDTH = 32,
    parameter SCALE = 3
) (
    input                  aclk,
    input                  aresetn,
    // slave (input) side
    input      [WIDTH-1:0] s_axis_tdata,
    input                  s_axis_tvalid,
    input                  s_axis_tlast,
    output reg             s_axis_tready,
    // master (output) side
    output reg [WIDTH-1:0] m_axis_tdata,
    output reg             m_axis_tvalid,
    output reg             m_axis_tlast,
    input                  m_axis_tready
);

    // skid storage
    reg [WIDTH-1:0] skid_data;
    reg             skid_last;
    reg             skid_full = 1'b0;

    wire in_fire   = s_axis_tvalid && s_axis_tready;
    wire out_fire  = m_axis_tvalid && m_axis_tready;
    wire out_free  = !m_axis_tvalid || out_fire;   // output reg can take a beat

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axis_tready <= 1'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            skid_full     <= 1'b0;
        end else begin
            if (out_free) begin
                // output register refills: skid first (order!), else input
                if (skid_full) begin
                    m_axis_tdata  <= skid_data * SCALE;
                    m_axis_tlast  <= skid_last;
                    m_axis_tvalid <= 1'b1;
                    // the skid slot frees - unless an incoming beat takes
                    // it over in the same cycle (drain + accept together)
                    if (in_fire) begin
                        skid_data <= s_axis_tdata;
                        skid_last <= s_axis_tlast;
                        skid_full <= 1'b1;
                    end else begin
                        skid_full <= 1'b0;
                    end
                end else if (in_fire) begin
                    m_axis_tdata  <= s_axis_tdata * SCALE;
                    m_axis_tlast  <= s_axis_tlast;
                    m_axis_tvalid <= 1'b1;
                end else begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                end
            end else if (in_fire) begin
                // output stuck and a beat just landed: into the skid.
                // (skid_full && in_fire while stuck is impossible - the
                // tready equation below guarantees it.)
                skid_data <= s_axis_tdata;
                skid_last <= s_axis_tlast;
                skid_full <= 1'b1;
            end

            // Registered ready = "will there be at least one free slot
            // next cycle?", computed from next-cycle occupancy:
            //   out stays/becomes full unless nothing refills it;
            //   skid ends full if (draining && refilled) or (stuck && beat landed).
            s_axis_tready <= out_free ? !(skid_full && in_fire)
                                      : !(skid_full || in_fire);
        end
    end

endmodule
