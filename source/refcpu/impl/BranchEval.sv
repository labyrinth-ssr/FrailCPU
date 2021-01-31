`include "refcpu/defs.svh"

module BranchEval (
    input  context_t ctx,
    output context_t out
);
    /**
     * in:
     *   t[0]: fetched instruction
     * out:
     *   t[0]: next PC
     */

    localparam type offset_t = logic [17:0];

    `FORMAT_ITYPE(opcode, rs, rt, imm, ctx.t[0]);

    word_t val1, val2;
    assign val1 = ctx.r[rs];
    assign val2 = ctx.r[rt];

    addr_t target_pc;
    offset_t offset;
    assign offset = {imm, 2'b0};
    assign target_pc = ctx.next_pc + `SIGN_EXTEND(offset);

    always_comb begin
        out = ctx;
        out.state = S_BRANCH;

        unique case (opcode)
        OP_BEQ:
            out.t[0] = val1 == val2 ? target_pc : ctx.next_pc;
        OP_BNE:
            out.t[0] = val1 != val2 ? target_pc : ctx.next_pc;
        default:
            out.state = S_UNKNOWN;
        endcase

        // UNPREDICTABLE: branch in delay slot
        if (ctx.delayed)
            out.state = S_UNKNOWN;
    end
endmodule
