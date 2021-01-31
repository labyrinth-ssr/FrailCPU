`include "refcpu/defs.svh"

module Exception (
    input  context_t ctx,
    output context_t out
);
    always_comb begin
        out = ctx;

        // TODO: implement exception handler
        out.state = S_UNKNOWN;
    end
endmodule
