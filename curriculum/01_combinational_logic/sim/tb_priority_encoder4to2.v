`timescale 1ns / 1ps

// Exhaustive over all 16 possible request patterns, including ones with
// multiple bits set at once - that's the whole point of testing a priority
// encoder rather than a plain one: cases like req=4'b1010 are where a wrong
// implementation (e.g. lowest-bit-wins instead of highest-bit-wins) would
// actually get caught.
module tb_priority_encoder4to2;

    reg  [3:0] req;
    wire       valid;
    wire [1:0] idx;
    reg        exp_valid;
    reg  [1:0] exp_idx;
    integer errors = 0;
    integer i;

    priority_encoder4to2 dut (.req(req), .valid(valid), .idx(idx));

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            req = i[3:0];
            #1;
            if (req[3])      begin exp_valid = 1'b1; exp_idx = 2'd3; end
            else if (req[2]) begin exp_valid = 1'b1; exp_idx = 2'd2; end
            else if (req[1]) begin exp_valid = 1'b1; exp_idx = 2'd1; end
            else if (req[0]) begin exp_valid = 1'b1; exp_idx = 2'd0; end
            else              begin exp_valid = 1'b0; exp_idx = 2'd0; end

            if (valid !== exp_valid || idx !== exp_idx) begin
                errors = errors + 1;
                $display("FAIL req=%b got=(valid=%b,idx=%0d) exp=(valid=%b,idx=%0d)",
                          req, valid, idx, exp_valid, exp_idx);
            end
        end

        if (errors == 0) $display("PASS: tb_priority_encoder4to2 - all 16 request combinations correct");
        else              $display("FAIL: tb_priority_encoder4to2 - %0d error(s)", errors);
        $finish;
    end

endmodule
