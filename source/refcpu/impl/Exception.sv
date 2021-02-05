`include "refcpu/defs.svh"

module Exception (
    input  context_t ctx,
    output context_t out
);
    ecode_t ecode;
    assign ecode = ctx.args.exception.code;

    always_comb begin
        out = ctx;
        out.state = S_FETCH;

        if (ctx.cp0.r.Status.ERL)
            `FATAL

        // fill CP0 registers
        if (!ctx.cp0.r.Status.EXL) begin
            out.cp0.r.Cause.BD = ctx.delayed;
            out.cp0.r.EPC = ctx.delayed ? ctx.pc : ctx.pc - 4;
        end

        out.cp0.r.Status.EXL = 1;
        out.cp0.r.BadVAddr = ctx.args.exception.bad_vaddr;
        out.cp0.r.Cause.ExcCode = ecode;

        // evaluate exception vector
        if (ecode == EX_INT) begin
            if (ctx.cp0.r.Status.EXL || ctx.cp0.r.Status.ERL)
                `FATAL

            unique case ({ctx.cp0.r.Status.BEV, ctx.cp0.r.Cause.IV})
                2'b00: out.pc = 32'h80000180;
                2'b01: out.pc = 32'h80000200;
                2'b10: out.pc = 32'hbfc00380;
                2'b11: out.pc = 32'hbfc00400;
            endcase
        end else
            out.pc = ctx.cp0.r.Status.BEV ?
                32'h80000180 : 32'hbfc00380;
    end
endmodule
