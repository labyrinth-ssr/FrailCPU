`include "refcpu/Defs.svh"

module Decode (
    input  context_t ctx,
    output context_t out
);
    opcode_t opcode;
    funct_t funct;
    regid_t rs, rt, rd, shamt;
    imm_t imm;

    assign {opcode, rs, rt, rd, shamt, funct} = ctx.t[0];
    assign imm = ctx.t[0][15:0];

    always_comb begin
        out = ctx;

        case (opcode)
        OP_NOP:
            out.state = COMMIT;
        default:  // unknown instruction
            out.state = UNKNOWN;
        endcase
    end

    logic _unused_ok = &{funct, rs, rt, rd, shamt, imm};
endmodule