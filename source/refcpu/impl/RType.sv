`include "refcpu/defs.svh"

module RType (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_RTYPE(rs, rt, rd, shamt, funct, ctx.instr);

    addr_t link_pc;
    assign link_pc = ctx.pc + 8;

    arith_t v_rs, v_rt, v_add, v_sub;
    assign v_rs = `SIGN_EXTEND(ctx.r[rs], 33);
    assign v_rt = `SIGN_EXTEND(ctx.r[rt], 33);
    assign v_add = v_rs + v_rt;
    assign v_sub = v_rs - v_rt;

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;
        out.target_id = rd;

        unique case (funct)
        FN_SLL:
            out.r[rd] = ctx.r[rt] << shamt;
        FN_SRL:
            out.r[rd] = ctx.r[rt] >> shamt;
        FN_SRA:
            out.r[rd] = $signed(ctx.r[rt]) >>> shamt;
        FN_SRLV:
            out.r[rd] = ctx.r[rt] >> ctx.r[rs][4:0];
        FN_SRAV:
            out.r[rd] = $signed(ctx.r[rt]) >>> ctx.r[rs][4:0];
        FN_SLLV:
            out.r[rd] = ctx.r[rt] << ctx.r[rs][4:0];
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

        FN_ADD: begin
            if (v_add[32] != v_add[31]) begin
                out.state = S_EXCEPTION;
                out.target_id = R0;
                out.args.exception.code = EX_OV;
            end else
                out.r[rd] = v_add[31:0];
        end

        FN_SUB: begin
            if (v_sub[32] != v_sub[31]) begin
                out.state = S_EXCEPTION;
                out.target_id = R0;
                out.args.exception.code = EX_OV;
            end else
                out.r[rd] = v_sub[31:0];
        end

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
