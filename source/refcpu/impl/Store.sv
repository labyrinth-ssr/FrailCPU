`include "refcpu/defs.svh"

module Store (
    input  context_t   ctx,
    output context_t   out,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    assign dreq.valid = 1;
    assign dreq.addr = ctx.args.mem.addr;
    assign dreq.size = ctx.args.mem.size;
    assign dreq.strobe = 4'b1111;
    assign dreq.data = ctx.r[`ITYPE_RT];

    always_comb begin
        out = ctx;

        `MEM_WAIT(dresp, S_STORE, S_STORE_ADDR_SENT, S_COMMIT);
    end

    logic _unused_ok = &{dresp.data};
endmodule
