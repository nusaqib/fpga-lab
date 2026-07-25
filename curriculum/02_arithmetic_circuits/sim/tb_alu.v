`timescale 1ns / 1ps

// Exhaustive over all 4 ops x 256 (a,b) combinations = 1024 cases. The
// expected model for SUB is the part worth reading closely: result wraps
// modulo 16 exactly like two's-complement hardware does (a 4-bit reg
// assignment truncates automatically), and cout is expected to read
// (a >= b) - i.e. "no borrow occurred" - not a traditional signed-overflow
// flag. See alu.v's header comment for why.
module tb_alu;

    localparam WIDTH = 4;
    localparam [1:0] ALU_ADD = 2'b00, ALU_SUB = 2'b01, ALU_AND = 2'b10, ALU_OR = 2'b11;

    reg  [WIDTH-1:0] a, b;
    reg  [1:0]       op;
    wire [WIDTH-1:0] result;
    wire             cout;
    reg  [WIDTH-1:0] exp_result;
    reg              exp_cout;
    reg  [WIDTH:0]   wide_sum;
    integer errors = 0;
    integer ai, bi, oi;

    alu #(.WIDTH(WIDTH)) dut (.a(a), .b(b), .op(op), .result(result), .cout(cout));

    initial begin
        for (oi = 0; oi < 4; oi = oi + 1) begin
            op = oi[1:0];
            for (ai = 0; ai < 16; ai = ai + 1) begin
                for (bi = 0; bi < 16; bi = bi + 1) begin
                    a = ai[WIDTH-1:0]; b = bi[WIDTH-1:0];
                    #1;

                    case (op)
                        ALU_ADD: begin
                            wide_sum   = a + b;
                            exp_result = wide_sum[WIDTH-1:0];
                            exp_cout   = wide_sum[WIDTH];
                        end
                        ALU_SUB: begin
                            exp_result = a - b;      // 4-bit reg: wraps mod 16, matches two's complement
                            exp_cout   = (a >= b);    // no borrow
                        end
                        ALU_AND: begin exp_result = a & b; exp_cout = 1'b0; end
                        ALU_OR:  begin exp_result = a | b; exp_cout = 1'b0; end
                    endcase

                    if (result !== exp_result || cout !== exp_cout) begin
                        errors = errors + 1;
                        $display("FAIL op=%b a=%0d b=%0d got=(result=%0d,cout=%b) exp=(result=%0d,cout=%b)",
                                  op, a, b, result, cout, exp_result, exp_cout);
                    end
                end
            end
        end

        if (errors == 0) $display("PASS: tb_alu - all 1024 op/a/b combinations correct");
        else              $display("FAIL: tb_alu - %0d error(s)", errors);
        $finish;
    end

endmodule
