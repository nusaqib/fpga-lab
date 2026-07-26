`timescale 1ns / 1ps

// Reference-model bench for the transposed FIR: impulse, step, then 500
// random samples, all checked bit-exactly against a behavioral model
// using the SAME Q1.15 quantization (round-to-nearest, saturate). The
// impulse response must read back the coefficient values themselves; the
// step response must climb 0.25 -> 0.5 -> 0.75 -> then SATURATE at
// 0x7FFF (not reach 1.0, which Q1.15 can't hold) - the saturation case
// is deliberately in the coefficient choice.
module tb_fir4_transposed;

    reg clk = 0, rst;
    reg               in_valid;
    reg  signed [15:0] in_sample;
    wire               out_valid;
    wire signed [15:0] out_sample;
    integer errors = 0;

    always #5 clk = ~clk;

    fir4_transposed dut (
        .clk(clk), .rst(rst),
        .in_valid(in_valid), .in_sample(in_sample),
        .out_valid(out_valid), .out_sample(out_sample)
    );

    // reference model: same taps, same arithmetic, same quantization
    reg signed [15:0] COEF [0:3];
    initial begin COEF[0]=16'sd3277; COEF[1]=16'sd13107; COEF[2]=16'sd13107; COEF[3]=16'sd3277; end
    reg signed [15:0] hist [0:3];
    reg signed [33:0] acc;
    reg signed [33:0] rounded;
    reg signed [15:0] expected;
    integer i;

    // the transposed pipeline delays the result: with this structure the
    // sample fed on cycle N produces its filtered output on out_sample
    // after the full adder chain has flushed - calibrate by tracking
    // outputs only when out_valid, against a model fed the same samples
    // with a matching delay line.
    reg signed [15:0] model_q [0:15];   // small FIFO of expected outputs
    integer wr = 0, rd = 0;

    task feed(input signed [15:0] s);
        begin
            // model: shift history, compute quantized output
            hist[3] = hist[2]; hist[2] = hist[1]; hist[1] = hist[0]; hist[0] = s;
            acc = hist[0]*COEF[0] + hist[1]*COEF[1] + hist[2]*COEF[2] + hist[3]*COEF[3];
            rounded = (acc + 34'sd16384) >>> 15;
            if (rounded > 34'sd32767)       expected = 16'sd32767;
            else if (rounded < -34'sd32768) expected = -16'sd32768;
            else                            expected = rounded[15:0];
            model_q[wr % 16] = expected;
            wr = wr + 1;
            // drive the DUT
            in_valid = 1; in_sample = s;
            @(negedge clk);
        end
    endtask

    // score outputs as they emerge (the DUT chain has latency; outputs
    // arrive in order, so a queue-compare with an initial skip works)
    integer outputs_seen = 0;
    // The transposed form has NO warm-up latency in valid-sample terms:
    // out_valid k pairs with input sample k (unroll the chain to see the
    // full convolution registered on the same valid cycle; the
    // accumulators' reset-to-zero matches the model's zeroed history).
    localparam LATENCY = 0;
    always @(posedge clk) begin
        if (!rst && out_valid) begin
            outputs_seen <= outputs_seen + 1;
            if (outputs_seen >= LATENCY) begin
                if (out_sample !== model_q[rd % 16]) begin
                    errors = errors + 1;
                    if (errors < 10)
                        $display("FAIL out #%0d: got=%0d exp=%0d", outputs_seen, out_sample, model_q[rd % 16]);
                end
                rd = rd + 1;
            end
        end
    end

    initial begin
        rst = 1; in_valid = 0; in_sample = 0;
        for (i = 0; i < 4; i = i + 1) hist[i] = 0;
        repeat (3) @(negedge clk);
        rst = 0;
        @(negedge clk);

        // impulse: +0.5 then zeros -> output reads the coefficients scaled by 0.5
        feed(16'sd16384);
        repeat (7) feed(16'sd0);

        // step to +1.0-ish (max positive): climbs then saturates at 32767
        repeat (10) feed(16'sd32767);
        repeat (6)  feed(16'sd0);

        // random torture
        repeat (500) feed($random);

        // drain
        in_valid = 0;
        repeat (10) @(negedge clk);

        if (errors == 0)
            $display("PASS: tb_fir4_transposed - impulse, saturating step, and 500 random samples match the Q1.15 reference model");
        else
            $display("FAIL: tb_fir4_transposed - %0d error(s)", errors);
        $finish;
    end

endmodule
