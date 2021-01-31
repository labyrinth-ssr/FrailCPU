`include "refcpu/defs.svh"
`include "refcpu/impl.svh"

module Core (
    input logic clk, resetn,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    context_t ctx /* verilator public_flat_rd */;
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
    `IMPL_Cxx(S_BRANCH_EVAL, BranchEval);
    `IMPL_Cxx(S_BRANCH, Branch);
    `IMPL_Cxx(S_UNSIGNED_ARITHMETIC, UnsignedArithmetic);
    `IMPL_Cxx(S_RTYPE, RType);

    /**
     * END state implementer declarations
     */
endmodule
