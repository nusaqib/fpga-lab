`timescale 1ns / 1ps

// Bench for the I2C stack: a behavioral ADT7420 written HERE, in the
// bench, playing the real chip - register pointer, auto-increment,
// address matching, ACK/NACK, the works. Writing the slave model is
// half the lesson: you don't understand a protocol until you've been
// both ends of it.
//
// Checks: ID transaction (0x0B -> 0xCB), a +25.5C reading, then the
// registers change and a -10.25C reading must come through, and
// bus_error must stay low throughout.
module tb_adt7420;

    reg clk = 0;
    always #5 clk = ~clk;          // 100 MHz

    // open-drain bus with pull-ups (tri1 = net with implicit pull-up)
    tri1 scl, sda;

    // ---------------- DUT: master + reader ----------------
    wire scl_pull, sda_pull;
    assign scl = scl_pull ? 1'b0 : 1'bz;
    assign sda = sda_pull ? 1'b0 : 1'bz;

    wire        cmd_valid, rd_ack, busy, ack_error;
    wire [1:0]  cmd;
    wire [7:0]  wdata, rdata;
    wire [12:0] temp;
    wire        temp_valid, id_ok, bus_error;

    // sim-friendly speeds: 1 MHz I2C, fast polling
    i2c_master #(.CLK_HZ(100_000_000), .I2C_HZ(1_000_000)) u_i2c (
        .clk(clk), .rst(1'b0),
        .cmd_valid(cmd_valid), .cmd(cmd), .wdata(wdata), .rd_ack(rd_ack),
        .busy(busy), .rdata(rdata), .ack_error(ack_error),
        .scl_i(scl), .scl_pull(scl_pull),
        .sda_i(sda), .sda_pull(sda_pull)
    );

    adt7420_reader #(.CLK_HZ(100_000_000), .POLL_HZ(20_000)) u_reader (
        .clk(clk), .rst(1'b0),
        .temp(temp), .temp_valid(temp_valid),
        .id_ok(id_ok), .bus_error(bus_error),
        .cmd_valid(cmd_valid), .cmd(cmd), .wdata(wdata), .rd_ack(rd_ack),
        .busy(busy), .rdata(rdata), .ack_error(ack_error)
    );

    // ---------------- behavioral ADT7420 ----------------
    reg [7:0] mem [0:255];
    reg       slv_pull = 0;        // slave pulls SDA low
    assign sda = slv_pull ? 1'b0 : 1'bz;

    localparam [6:0] MY_ADDR = 7'h4B;

    integer  sstate = 0;           // 0 idle, 1 addr, 2 wdata, 3 rdata
    integer  bitcnt = 0;
    reg      ack_phase = 0;
    reg      mode_read = 0;
    reg      addressed = 0;
    reg      master_acked = 0;
    reg [7:0] shin = 0, shout = 0;
    reg [7:0] regptr = 0;
    reg      first_write = 0;

    // START (SDA falls, SCL high) resets the byte engine; STOP idles it.
    always @(negedge sda) if (scl === 1'b1) begin
        sstate    = 1;
        bitcnt    = 0;
        ack_phase = 0;
        slv_pull  = 0;
    end
    always @(posedge sda) if (scl === 1'b1) begin
        sstate   = 0;
        slv_pull = 0;
    end

    // sample on SCL rising
    always @(posedge scl) if (sstate != 0) begin
        if (!ack_phase) begin
            if (sstate != 3)
                shin = {shin[6:0], sda};
            bitcnt = bitcnt + 1;
        end else if (sstate == 3) begin
            master_acked = (sda === 1'b0);
        end
    end

    // drive after SCL falling (data changes while SCL low)
    always @(negedge scl) if (sstate != 0) begin
        #100;   // slave data setup delay
        if (!ack_phase && bitcnt == 8) begin
            ack_phase = 1;
            case (sstate)
                1: begin
                    addressed = (shin[7:1] == MY_ADDR);
                    mode_read = shin[0];
                    slv_pull  = addressed;      // ACK own address
                    if (addressed && mode_read)
                        shout = mem[regptr];
                end
                2: begin
                    slv_pull = 1'b1;            // ACK the write byte
                    if (first_write) begin
                        regptr = shin;
                        first_write = 0;
                    end
                end
                3: slv_pull = 1'b0;             // release for master ACK
            endcase
        end else if (ack_phase) begin
            ack_phase = 0;
            bitcnt = 0;
            slv_pull = 0;
            if (sstate == 1) begin
                if (!addressed)
                    sstate = 0;
                else if (mode_read) begin
                    sstate = 3;
                    slv_pull = ~shout[7];       // first data bit now
                end else begin
                    sstate = 2;
                    first_write = 1;
                end
            end else if (sstate == 3) begin
                if (master_acked) begin
                    regptr = regptr + 1;        // auto-increment
                    shout = mem[regptr];
                    slv_pull = ~shout[7];
                end else
                    sstate = 0;                 // NACK: master is done
            end
        end else if (sstate == 3 && !ack_phase) begin
            // shift out the next read bit (bitcnt already advanced)
            shout = {shout[6:0], 1'b0};
            slv_pull = ~shout[7];
        end
    end

    // ---------------- the actual test ----------------
    integer errors = 0;
    integer reads = 0;

    task expect_temp(input [12:0] want);
        begin
            @(posedge temp_valid);
            if (temp !== want) begin
                $display("FAIL: temp = %0d (0x%04x), expected %0d",
                         temp, temp, want);
                errors = errors + 1;
            end else
                $display("  temp reading %0d ok (0x%04x)", temp, temp);
            reads = reads + 1;
        end
    endtask

    initial begin
        // +25.5 C -> 408 lsb; 13-bit value packed {msb, lsb[7:3]}
        mem[8'h00] = 8'h0C;         // 408 >> 5
        mem[8'h01] = 8'hC0;         // (408 & 31) << 3
        mem[8'h0B] = 8'hCB;         // device ID

        // identify happens first; then temp reads
        expect_temp(13'd408);
        if (!id_ok) begin
            $display("FAIL: id_ok not set after identify");
            errors = errors + 1;
        end

        // change the "temperature" to -10.25 C = -164 -> 8028 as 13-bit
        mem[8'h00] = 8'hFA;         // 8028 >> 5
        mem[8'h01] = 8'hE0;         // (8028 & 31) << 3
        expect_temp(13'd8028);

        if (bus_error) begin
            $display("FAIL: bus_error asserted");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: ADT7420 stack - ID + two temperature reads");
        else
            $display("FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #20_000_000;                // 20 ms wall clock at 1 MHz I2C
        $display("FAIL: timeout (reads completed: %0d)", reads);
        $finish;
    end

endmodule
