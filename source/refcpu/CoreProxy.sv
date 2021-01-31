`include "refcpu/defs.svh"

module CoreProxy (
    input logic clk, resetn,

    input context_t  [LAST_CPU_STATE:0] out_ctx,
    input ibus_req_t [LAST_CPU_STATE:0] out_ireq,
    input dbus_req_t [LAST_CPU_STATE:0] out_dreq,

    output context_t  ctx, ctx0,
    output ibus_req_t ireq,
    output dbus_req_t dreq
);
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

        // reset args
        if (ctx.state == S_COMMIT)
            new_ctx.args = ARGS_RESET_VALUE;
    end

    always_ff @(posedge clk)
    if (resetn) begin
        // stop when CPU trapped in S_UNKNOWN
        if (ctx.state == S_UNKNOWN) begin
            $display("ctx.pc=%08x\n", ctx.pc);
            $finish;
        end

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
