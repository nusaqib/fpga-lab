`timescale 1ns / 1ps

// Hardware demo: a 4-bit register that captures the switches while the
// button is held and freezes when released - "LEDs remember what the
// switches were when you let go." First clocked design in the curriculum.
//
// The button goes through sync2 before it touches the register's enable -
// a button is an asynchronous input, and this is the honest way to bring
// one into a clock domain (see sync2.v). Note what is deliberately NOT
// here: debouncing. A level-sensitive enable doesn't care about bounce
// (the register just re-captures a few extra times while the contacts
// settle), but edge-triggered logic would - which is exactly module 04's
// opening problem.
module capture_top (
    input        clk,
    input        btn,
    input  [3:0] sw,
    output [3:0] led
);

    wire btn_s;

    sync2 u_sync (
        .clk      (clk),
        .async_in (btn),
        .sync_out (btn_s)
    );

    register_en #(.WIDTH(4)) u_reg (
        .clk (clk),
        .rst (1'b0),
        .en  (btn_s),
        .d   (sw),
        .q   (led)
    );

endmodule
