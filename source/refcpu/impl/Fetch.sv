`include "refcpu/defs.svh"

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
        out.instr = iresp.data;

        `MEM_WAIT(iresp, S_FETCH, S_FETCH_ADDR_SENT, S_DECODE);

        // PC must be aligned on word boundry.
        if (|ctx.pc[1:0])
            `ADDR_ERROR(EX_ADEL, ctx.pc)
    end
endmodule
