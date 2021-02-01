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

        OP_BEQ, OP_BNE,
        OP_J, OP_JAL:
            out.state = S_BRANCH_EVAL;

        OP_ADDIU,
        OP_SLTI, OP_SLTIU,
        OP_ANDI, OP_ORI, OP_XORI,
        OP_LUI:
            out.state = S_UNSIGNED_ARITHMETIC;

        OP_LW, OP_SW:
            out.state = S_ADDR_CHECK;

        default: begin  // unknown instruction
            out.state = S_EXCEPTION;
            out.args.exception.code = EX_RI;
        end

        endcase
    end
endmodule
