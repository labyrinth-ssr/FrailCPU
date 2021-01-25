`include "refcpu/defs.svh"

module Branch (
    input  context_t ctx,
    output context_t out
);
    /**
     * in:
     *   t[0]: next PC
     */

    // NOTE: branch instruction would not be committed until
    //       its delay slot has been committed.
    always_comb begin
        out = ctx;
        out.state = S_FETCH;  // skip S_COMMIT
        out.pc = ctx.next_pc;
        out.delayed = 1;
        out.delayed_pc = ctx.t[0];
    end
endmodule
