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

        // PC must be aligned to 4 bytes
        if (|ctx.pc[1:0]) begin
            out.state = S_EXCEPTION;
            out.args.exception.code = EX_ADEL;
        end
    end
endmodule
