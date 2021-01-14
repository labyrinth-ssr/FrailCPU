`include "refcpu/Defs.svh"

/**
 * shortcuts for module instantiation.
 * these macros will connect ports to corresponding out_* array entries.
 * the ".*" syntax is used to automatically connect input ports.
 * unconnected out ports will be assigned to zeros.
 *
 * M: module name
 * S: state name
 */
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
     * ctx0 is a snapshot of ctx at the beginning of the execution
     * of each instruction, which is reserved for debugging and
     * external interrupts(?).
     * in COMMIT stage, ctx will be saved to ctx0.
     */
    context_t ctx, ctx0 /* verilator public_flat_rd */;

    // stage outputs
    ibus_req_t [LAST_CPU_STATE:0] out_ireq;
    dbus_req_t [LAST_CPU_STATE:0] out_dreq;
    context_t  [LAST_CPU_STATE:0] out_ctx;

    `DECLARE_CID(Unknown, S_UNKNOWN);
    `DECLARE_CI(Fetch, S_FETCH);
    `DECLARE_C(Decode, S_DECODE);
    `DECLARE_C(Commit, S_COMMIT);

    // IO requests
    assign ireq = out_ireq[ctx.state];
    assign dreq = out_dreq[ctx.state];

    // update context
    context_t new_ctx;

    always_comb begin
        new_ctx = out_ctx[ctx.state];

        // (fake) hardwired values
        new_ctx.r[0] = '0;
        new_ctx.next_pc = new_ctx.pc + 4;

        // detect invalid state
        if (new_ctx.state > LAST_CPU_STATE)
            new_ctx.state = S_UNKNOWN;
    end

    always_ff @(posedge clk)
    if (resetn) begin
        ctx <= new_ctx;

        // checkpoint context at COMMIT
        if (ctx.state == S_COMMIT)
            ctx0 <= new_ctx;
    end else begin
        {ctx, ctx0} <= {2{CONTEXT_RESET_VALUE}};
    end

    // for Verilator
    logic _unused_ok = &{ctx0, iresp, dresp};
endmodule

`undef DECLARE_C
`undef DECLARE_CI
`undef DECLARE_CD
`undef DECLARE_CID
