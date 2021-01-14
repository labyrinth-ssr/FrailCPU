`include "refcpu/Defs.svh"

// shortcuts for module instantiation
`define DECLARE_C(M, S) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .*); \
    assign {out_ireq[S], out_dreq[S]} = '0;
`define DECLARE_CI(M, S) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .ireq(out_ireq[S]), .*); \
    assign out_dreq[S] = '0;
`define DECLARE_CD(M, S) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .dreq(out_dreq[S]), .*); \
    assign out_ireq[S] = '0;

// it's generally rare that an instruction interacts with
// both instruction cache and data cache simultaneously...
`define DECLARE_CID(M, S) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .ireq(out_ireq[S]), .dreq(out_dreq[S]), .*);

module RefCPU (
    input logic clk, resetn,

    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t  dreq,
    input  dbus_resp_t dresp
);
    /**
     * _ctx is a snapshot of ctx at the beginning of the execution
     * of each instruction, which is reserved for debugging and
     * external interrupts(?).
     * in COMMIT stage, ctx will be saved to _ctx.
     */
    context_t ctx, _ctx;

    // module outputs
    ibus_req_t [LAST_STATE:0] out_ireq;
    dbus_req_t [LAST_STATE:0] out_dreq;
    context_t  [LAST_STATE:0] out_ctx;

    /**
     * the state machine
     */

    // the UNKNOWN indicates that CPU was trapped in an error,
    // and infinitely loops.
    assign out_ireq[UNKNOWN] = '0;
    assign out_dreq[UNKNOWN] = '0;
    assign out_ctx[UNKNOWN] = ctx;

    `DECLARE_CI(Fetch, FETCH);
    `DECLARE_C(Decode, DECODE);
    `DECLARE_C(Commit, COMMIT);

    // IO requests
    assign ireq = out_ireq[ctx.state];
    assign dreq = out_dreq[ctx.state];

    // update context
    context_t new_ctx;

    always_comb begin
        new_ctx = out_ctx[ctx.state];

        // detect invalid state
        if (new_ctx.state > LAST_STATE)
            new_ctx.state = UNKNOWN;
    end

    always_ff @(posedge clk)
    if (resetn) begin
        ctx <= new_ctx;

        // checkpoint context at COMMIT
        if (ctx.state == COMMIT)
            _ctx <= new_ctx;
    end else begin
        {ctx, _ctx} <= {2{RESET_CONTEXT}};
    end

    // for Verilator
    logic _unused_ok = &{_ctx, iresp, dresp};
endmodule