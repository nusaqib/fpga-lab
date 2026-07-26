`timescale 1ns / 1ps

// Reference-model bench for the shift register, plus one directed check:
// after loading a known word and shifting WIDTH times, the bits that fell
// out of serial_out are exactly that word, MSB first - the "serialize a
// word" property that makes shift registers the heart of UART/SPI later.
module tb_shift_register;

    localparam WIDTH = 4;
    localparam CYCLES = 400;

    reg              clk = 0, rst, en, load, serial_in;
    reg  [WIDTH-1:0] d;
    wire [WIDTH-1:0] q;
    wire             serial_out;
    reg  [WIDTH-1:0] model;
    reg  [WIDTH-1:0] captured;
    integer errors = 0;
    integer i;

    always #5 clk = ~clk;

    shift_register #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst(rst), .en(en), .serial_in(serial_in),
        .load(load), .d(d), .q(q), .serial_out(serial_out)
    );

    initial begin
        rst = 1; en = 0; load = 0; serial_in = 0; d = 0; model = 0;
        @(negedge clk);
        rst = 0;

        // --- random phase against the model ---
        for (i = 0; i < CYCLES; i = i + 1) begin
            en        = $random;
            load      = ($random % 4 == 0);
            serial_in = $random;
            d         = $random;
            rst       = ($random % 16 == 0);

            if (rst)       model = 0;
            else if (load) model = d;
            else if (en)   model = {model[WIDTH-2:0], serial_in};

            @(negedge clk);

            if (q !== model) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: q=%h model=%h", i, q, model);
            end
            if (serial_out !== model[WIDTH-1]) begin
                errors = errors + 1;
                $display("FAIL cycle %0d: serial_out=%b exp=%b", i, serial_out, model[WIDTH-1]);
            end
        end

        // --- directed serialization check ---
        rst = 1; en = 0; load = 0;
        @(negedge clk);
        rst = 0;
        d = 4'b1011; load = 1; en = 0;
        @(negedge clk);
        load = 0; en = 1; serial_in = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            captured = {captured[WIDTH-2:0], serial_out};  // sample before the shift edge lands
            @(negedge clk);
        end
        en = 0;
        if (captured !== 4'b1011) begin
            errors = errors + 1;
            $display("FAIL serialization: captured=%b exp=1011", captured);
        end

        if (errors == 0) $display("PASS: tb_shift_register - model match over %0d cycles + word serialized MSB-first", CYCLES);
        else              $display("FAIL: tb_shift_register - %0d error(s)", errors);
        $finish;
    end

endmodule
