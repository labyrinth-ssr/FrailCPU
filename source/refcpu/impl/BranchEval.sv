`include "refcpu/pkgs.svh"

import common::*;
import defs::*;

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

    opcode_t opcode;
    regid_t rs, rt;
    imm_t offset;
    assign {opcode, rs, rt, offset} = ctx.t[0];

    word_t val1, val2;
    assign val1 = ctx.r[rs];
    assign val2 = ctx.r[rt];

    addr_t target_pc;
    assign target_pc = ctx.next_pc + word_t'(offset);

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
    end
endmodule
