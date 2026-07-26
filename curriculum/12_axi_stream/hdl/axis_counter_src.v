`timescale 1ns / 1ps

// AXI-Stream master: on each `start` pulse, emits one packet of BEATS
// incrementing words. AXI-Stream is AXI with the addresses deleted: just
// TDATA qualified by the same valid/ready handshake, plus TLAST marking
// the final beat of a packet. The stream stalls (holding TVALID and TDATA
// steady, as the spec requires) whenever the downstream drops TREADY.
module axis_counter_src #(
    parameter WIDTH = 32,
    parameter BEATS = 16
) (
    input                  aclk,
    input                  aresetn,
    input                  start,          // one-cycle pulse: emit a packet
    output reg [WIDTH-1:0] m_axis_tdata,
    output reg             m_axis_tvalid,
    output reg             m_axis_tlast,
    input                  m_axis_tready,
    output reg [WIDTH-1:0] total_count = 0 // free-running sample counter (debug)
);

    localparam CW = $clog2(BEATS);
    reg [CW-1:0] beat = 0;
    reg          busy = 1'b0;

    always @(posedge aclk) begin
        if (!aresetn) begin
            busy          <= 1'b0;
            beat          <= 0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tdata  <= 0;
            total_count   <= 0;
        end else begin
            if (!busy && start) begin
                busy          <= 1'b1;
                beat          <= 0;
                m_axis_tvalid <= 1'b1;
                m_axis_tdata  <= total_count;   // pattern continues across packets
                m_axis_tlast  <= (BEATS == 1);
            end else if (busy && m_axis_tvalid && m_axis_tready) begin
                // beat accepted: advance or finish
                total_count <= total_count + 1'b1;
                if (m_axis_tlast) begin
                    busy          <= 1'b0;
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                end else begin
                    beat         <= beat + 1'b1;
                    m_axis_tdata <= total_count + 1'b1;
                    m_axis_tlast <= (beat == BEATS-2);
                end
            end
            // while stalled (tvalid && !tready): hold everything - the
            // absence of an else branch IS the spec compliance
        end
    end

endmodule
