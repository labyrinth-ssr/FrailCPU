`include "refcpu/Defs.svh"
`include "refcpu/Impl.svh"

module Core (
    input logic clk, resetn,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    context_t ctx;
    ibus_req_t [LAST_CPU_STATE:0] out_ireq;
    dbus_req_t [LAST_CPU_STATE:0] out_dreq;
    context_t  [LAST_CPU_STATE:0] out_ctx;

    CoreProxy proxy(.*);

    /**
     * BEGIN state implementer declarations
     */

    `IMPL_CID(S_UNKNOWN, Unknown);
    `IMPL_CIx(S_FETCH, Fetch);
    `IMPL_CIx(S_FETCH_ADDR_SENT, FetchAddrSent);
    `IMPL_Cxx(S_DECODE, Decode);
    `IMPL_Cxx(S_COMMIT, Commit);

    /**
     * END state implementer declarations
     */
endmodule
