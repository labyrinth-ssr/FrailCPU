`include "refcpu/defs.svh"

module Decode (
    input  context_t ctx,
    output context_t out
);
    /**
     * in:
     *   t[0]: fetched instruction
     * out:
     *   t[0]: fetched instruction
     */

    opcode_t opcode;
    assign opcode = ctx.t[0][31:26];

    always_comb begin
        out = ctx;

        unique case (opcode)
        OP_RTYPE:
            out.state = S_COMMIT;
        OP_BEQ, OP_BNE:
            out.state = S_BRANCH_EVAL;
        default:  // unknown instruction
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
