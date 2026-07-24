`timescale 1ns / 1ps

// Exhaustive: all 16 data patterns x all 4 select values = 64 checks.
// Small input spaces like this are exactly when exhaustive testing is
// cheap enough to just do, rather than picking a handful of "interesting"
// cases and hoping they're representative.
module tb_mux4to1;

    reg  [3:0] data;
    reg  [1:0] sel;
    wire       y;
    integer errors = 0;
    integer d, s;

    mux4to1 dut (.data(data), .sel(sel), .y(y));

    initial begin
        for (d = 0; d < 16; d = d + 1) begin
            data = d[3:0];
            for (s = 0; s < 4; s = s + 1) begin
                sel = s[1:0];
                #1;
                if (y !== data[sel]) begin
                    errors = errors + 1;
                    $display("FAIL data=%b sel=%0d got=%b exp=%b", data, sel, y, data[sel]);
                end
            end
        end

        if (errors == 0) $display("PASS: tb_mux4to1 - all 64 data/sel combinations correct");
        else              $display("FAIL: tb_mux4to1 - %0d error(s)", errors);
        $finish;
    end

endmodule
