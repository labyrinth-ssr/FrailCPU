`include "refcpu/Defs.svh"

module Commit (
    input  context_t ctx,
    output context_t out
);
    always_comb begin
        out = ctx;

        out.state = FETCH;

        if (ctx.is_delayed) begin
            out.is_delayed = 0;
            out.pc = ctx.delayed_pc;
        end else
            out.pc = ctx.pc + 4;
    end
endmodule