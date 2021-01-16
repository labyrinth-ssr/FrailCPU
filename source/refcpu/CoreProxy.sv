`include "refcpu/pkgs.svh"

import common::*;
import defs::*;

module CoreProxy (
    input logic clk, resetn,

    input context_t  [LAST_CPU_STATE:0] out_ctx,
    input ibus_req_t [LAST_CPU_STATE:0] out_ireq,
    input dbus_req_t [LAST_CPU_STATE:0] out_dreq,

    output context_t  ctx,
    output ibus_req_t ireq,
    output dbus_req_t dreq
);
    /**
     * ctx0 is a snapshot of ctx at the beginning of the execution
     * of each instruction, which is reserved for debugging and
     * external interrupts(?).
     * in COMMIT stage, ctx will be saved to ctx0.
     */
    context_t ctx0 /* verilator public_flat_rd */;

    assign ireq = out_ireq[ctx.state];
    assign dreq = out_dreq[ctx.state];

    /**
     * update context
     */

    context_t new_ctx;

    always_comb begin
        new_ctx = out_ctx[ctx.state];

        // (fake) hardwired values
        new_ctx.r[0] = '0;
        new_ctx.next_pc = new_ctx.pc + 4;

        // detect invalid state
        if (new_ctx.state > LAST_CPU_STATE)
            new_ctx.state = S_UNKNOWN;
    end

    always_ff @(posedge clk)
    if (resetn) begin
        ctx <= new_ctx;

        // checkpoint context at COMMIT
        if (ctx.state == S_COMMIT)
            ctx0 <= new_ctx;
    end else begin
        {ctx, ctx0} <= {2{CONTEXT_RESET_VALUE}};
    end

    // for Verilator
    logic _unused_ok = &{ctx0};
endmodule
