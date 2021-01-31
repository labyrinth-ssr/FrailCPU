`include "refcpu/defs.svh"

module RType (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_RTYPE(_unused_rs, rt, rd, shamt, funct, ctx.instr);

    always_comb begin
        out = ctx;
        out.state = S_COMMIT;
        out.args.commit.target_id = rd;

        unique case (funct)
        FN_SLL:
            out.r[rd] = ctx.r[rt] << shamt;
        default:
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
