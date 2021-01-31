`include "refcpu/defs.svh"

module UnsignedArithmetic (
    input  context_t ctx,
    output context_t out
);
    /**
     * in:
     *   t[0]: fetched instruction
     */

    `FORMAT_ITYPE(opcode, rs, rt, imm, ctx.t[0]);

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;

        unique case (opcode)
        OP_ADDIU:
            out.r[rt] = ctx.r[rs] + `SIGN_EXTEND(imm);
        default:
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
