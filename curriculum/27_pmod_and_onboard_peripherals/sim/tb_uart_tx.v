`timescale 1ns / 1ps

// uart_tx check: send two bytes back-to-back, receive them with a
// bit-banged 115200 sampler (mid-bit sampling, like a real UART).
module tb_uart_tx;

    reg clk = 0;
    always #5 clk = ~clk;

    reg  [7:0] data = 0;
    reg        valid = 0;
    wire       ready, txd;

    uart_tx dut (
        .clk(clk), .rst(1'b0),
        .data(data), .valid(valid), .ready(ready), .txd(txd)
    );

    localparam BITNS = 1_000_000_000 / 115_200;   // ~8680 ns

    integer errors = 0;

    // Sampled on NEGEDGE: right after a posedge, the DUT's nonblocking
    // updates (busy going active) haven't applied yet - a wait(ready)
    // there reads stale 1 and double-issues. Sampling half a cycle
    // later sidesteps the race. (Found the direct way.)
    task send(input [7:0] b);
        begin
            @(negedge clk);
            while (!ready) @(negedge clk);
            data <= b; valid <= 1;
            @(negedge clk);
            valid <= 0;
        end
    endtask

    task recv(input [7:0] exp_b);
        integer i;
        reg [7:0] got;
        begin
            @(negedge txd);                       // start bit edge
            #(BITNS + BITNS / 2);                 // middle of bit 0
            for (i = 0; i < 8; i = i + 1) begin
                got[i] = txd;
                #BITNS;
            end
            if (txd !== 1'b1) begin
                $display("FAIL: stop bit low");
                errors = errors + 1;
            end
            if (got !== exp_b) begin
                $display("FAIL: got 0x%02x expected 0x%02x", got, exp_b);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        fork
            begin send(8'hA5); send(8'h5A); end
            begin recv(8'hA5); recv(8'h5A); end
        join
        if (errors == 0) $display("PASS: uart_tx framing and data");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #2_000_000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
