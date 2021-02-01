`include "refcpu/defs.svh"

module RType (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_RTYPE(rs, rt, rd, shamt, funct, ctx.instr);

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;
        out.args.commit.target_id = rd;

        unique case (funct)
        FN_SLL:
            out.r[rd] = ctx.r[rt] << shamt;
        FN_ADDU:
            out.r[rd] = ctx.r[rs] + ctx.r[rt];
        FN_SUBU:
            out.r[rd] = ctx.r[rs] - ctx.r[rt];
        FN_AND:
            out.r[rd] = ctx.r[rs] & ctx.r[rt];
        FN_OR:
            out.r[rd] = ctx.r[rs] | ctx.r[rt];
        FN_XOR:
            out.r[rd] = ctx.r[rs] ^ ctx.r[rt];
        FN_NOR:
            out.r[rd] = ~(ctx.r[rs] | ctx.r[rt]);

        FN_JR: begin
            out.state = S_BRANCH;
            out.args.commit.target_id = R0;  // cancel writeback
            out.args.branch.new_pc = ctx.r[rs];
        end

        default: begin
            out.state = S_EXCEPTION;
            out.args.exception.code = EX_RI;
        end
        endcase
    end
endmodule
