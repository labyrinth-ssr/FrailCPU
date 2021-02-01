`include "refcpu/defs.svh"

module RType (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_RTYPE(rs, rt, rd, shamt, funct, ctx.instr);

    addr_t link_pc;
    assign link_pc = ctx.pc + 8;

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;
        out.target_id = rd;

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
        FN_SLT:
            out.r[rd] = `SIGNED_CMP(ctx.r[rs], ctx.r[rt]);
        FN_SLTU:
            out.r[rd] = `UNSIGNED_CMP(ctx.r[rs], ctx.r[rt]);

        FN_JR: begin
            out.state = S_BRANCH;
            out.target_id = R0;  // cancel writeback
            out.args.branch.new_pc = ctx.r[rs];
        end

        FN_JALR: begin
            out.state = S_BRANCH;
            out.r[rd] = link_pc;
            out.args.branch.new_pc = ctx.r[rs];
        end

        default: begin
            out.state = S_EXCEPTION;
            out.target_id = R0;  // cancel writeback
            out.args.exception.code = EX_RI;
        end
        endcase
    end
endmodule
