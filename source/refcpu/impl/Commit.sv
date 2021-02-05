`include "refcpu/defs.svh"

module Commit (
    input  context_t ctx,
    output context_t out
);
    always_comb begin
        out = ctx;
        out.state = S_FETCH;

        /**
         * update CP0
         */

        // invoke timer interrupt
        if (ctx.cp0.r.Count == ctx.cp0.r.Compare)
            out.cp0.r.Cause.IP[7] = 1;

        // increment Count
        out.cp0.r.Count = ctx.cp0.r.Count + 1;

        /**
         * update PC
         */

        // TODO: add interrupt checks

        if (ctx.delayed) begin
            out.delayed = 0;
            out.pc = ctx.delayed_pc;
        end else
            out.pc = ctx.pc + 4;
    end
endmodule
