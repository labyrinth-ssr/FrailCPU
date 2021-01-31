`include "refcpu/defs.svh"

module Debugger (
    input context_t ctx, ctx0,

    output addr_t   debug_wb_pc,
    output strobe_t debug_wb_rf_wen,
    output regidx_t debug_wb_rf_wnum,
    output word_t   debug_wb_rf_wdata
);
    int idx;
    logic changed;

    always_comb begin
        idx = 0;
        changed = 0;
        for (int i = 0; i < 32; i++) begin
            if (ctx.r[i] != ctx0.r[i]) begin
                idx = i;
                changed = 1;
                break;
            end
        end
    end

    assign debug_wb_pc = ctx.pc;
    assign debug_wb_rf_wen = ctx.state == S_COMMIT && changed ? 4'b1111 : 4'b0000;
    assign debug_wb_rf_wnum = regidx_t'(idx);
    assign debug_wb_rf_wdata = ctx.r[idx];

    logic _unused_ok = &{ctx, ctx0};
endmodule
