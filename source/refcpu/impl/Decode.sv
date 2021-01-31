`include "refcpu/defs.svh"

module Decode (
    input  context_t ctx,
    output context_t out
);
    always_comb begin
        out = ctx;

        unique case (ctx.instr.opcode)
        OP_RTYPE:
            out.state = S_RTYPE;

        OP_BEQ, OP_BNE:
            out.state = S_BRANCH_EVAL;

        OP_ADDIU,
        OP_ANDI, OP_ORI, OP_XORI,
        OP_LUI:
            out.state = S_UNSIGNED_ARITHMETIC;

        default:  // unknown instruction
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
