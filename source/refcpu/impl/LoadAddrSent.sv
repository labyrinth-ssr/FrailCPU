`include "refcpu/defs.svh"

module LoadAddrSent (
    input  context_t   ctx,
    output context_t   out,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    assign dreq = '0;

    always_comb begin
        out = ctx;
        out.r[`ITYPE_RT] = dresp.data;
        out.args.commit.target_id = `ITYPE_RT;
        out.state = dresp.data_ok ? S_COMMIT : S_STORE_ADDR_SENT;
    end

    logic _unused_ok = &{dresp.addr_ok};
endmodule
