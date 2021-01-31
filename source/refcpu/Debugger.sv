`include "refcpu/defs.svh"

module Debugger (
    input context_t ctx,

    output addr_t   debug_wb_pc,
    output strobe_t debug_wb_rf_wen,
    output regidx_t debug_wb_rf_wnum,
    output word_t   debug_wb_rf_wdata
);
    regid_t id;
    logic changed;

    assign id = ctx.args.commit.target_id;
    assign changed = ctx.state == S_COMMIT && |id;

    assign debug_wb_pc = ctx.pc;
    assign debug_wb_rf_wen = {4{changed}};
    assign debug_wb_rf_wnum = id;
    assign debug_wb_rf_wdata = ctx.r[id];

    logic _unused_ok = &{ctx};
endmodule
