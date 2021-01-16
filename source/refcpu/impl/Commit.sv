`include "refcpu/pkgs.svh"

import defs::*;

module Commit (
    input  context_t ctx,
    output context_t out
);
    always_comb begin
        out = ctx;
        out.state = S_FETCH;

        if (ctx.delayed) begin
            out.delayed = 0;
            out.pc = ctx.delayed_pc;
        end else
            out.pc = ctx.next_pc;
    end
endmodule
