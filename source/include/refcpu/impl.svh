`ifndef __REFCPU_IMPL_SVH__
`define __REFCPU_IMPL_SVH__

/**
 * shortcuts for implementer module instantiation.
 * these macros will connect ports to corresponding out_* array entries.
 * the ".*" syntax is used to automatically connect input ports.
 * unconnected out ports will be assigned to zeros.
 *
 * required out arrays: out_ctx, out_ireq, out_dreq
 *   - size: [LAST_CPU_STATE:0]
 *
 * S: state name
 * M: implementer module name
 *
 * name encoding:
 * C: this implementer has "ctx" and "out" ports.
 * I: this implementer has "ireq" and "iresp" ports.
 * D: this implementer has "dreq" and "dresp" ports.
 * x: corresponding ports are missed.
 */
`define IMPL_Cxx(S, M) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .*); \
    assign {out_ireq[S], out_dreq[S]} = '0;
`define IMPL_CIx(S, M) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .ireq(out_ireq[S]), .*); \
    assign out_dreq[S] = '0;
`define IMPL_CxD(S, M) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .dreq(out_dreq[S]), .*); \
    assign out_ireq[S] = '0;

// it's generally rare that an instruction interacts with
// both instruction cache and data cache simultaneously...
`define IMPL_CID(S, M) \
    M M``_inst_L```__LINE__(.out(out_ctx[S]), .ireq(out_ireq[S]), .dreq(out_dreq[S]), .*);

`endif