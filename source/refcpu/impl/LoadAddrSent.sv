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

        if (dresp.data_ok) begin
            out.r[`ITYPE_RT] = dresp.data;
            out.target_id = `ITYPE_RT;
            out.state = S_COMMIT;
        end else begin
            out.target_id = R0;
            out.state = S_LOAD_ADDR_SENT;
        end
    end

    logic _unused_ok = &{dresp.addr_ok};
endmodule
