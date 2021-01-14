`include "refcpu/Defs.svh"

module Fetch (
    input  context_t   ctx,
    output context_t   out,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp
);
    assign ireq.valid = 1;
    assign ireq.addr = ctx.pc;

    always_comb begin
        out = ctx;

        out.t[0] = iresp.data;
        out.state = iresp.data_ok ? S_DECODE : S_FETCH;
    end

    logic _unused_ok = &{iresp};
endmodule
