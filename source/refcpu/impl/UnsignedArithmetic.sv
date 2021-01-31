`include "refcpu/defs.svh"

module UnsignedArithmetic (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_ITYPE(opcode, rs, rt, imm, ctx.instr);

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;
        out.args.commit.target_id = rt;

        unique case (opcode)
        OP_ADDIU:
            out.r[rt] = ctx.r[rs] + `SIGN_EXTEND(imm);
        OP_ANDI:
            out.r[rt] = ctx.r[rs] & `ZERO_EXTEND(imm);
        OP_ORI:
            out.r[rt] = ctx.r[rs] | `ZERO_EXTEND(imm);
        OP_XORI:
            out.r[rt] = ctx.r[rs] ^ `ZERO_EXTEND(imm);
        OP_LUI:
            out.r[rt] = {imm, 16'b0};
        default:
            // Decode should guarantee that no other instruction
            // enters this state.
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
