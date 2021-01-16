`include "refcpu/pkgs.svh"

import common::regid_t;
import defs::*;

module Decode (
    input  context_t ctx,
    output context_t out
);
    opcode_t opcode;
    funct_t funct;
    regid_t rs, rt, rd;
    shamt_t shamt;
    imm_t imm;

    assign {opcode, rs, rt, rd, shamt, funct} = ctx.t[0];
    assign imm = ctx.t[0][15:0];

    always_comb begin
        out = ctx;

        unique case (opcode)
        OP_NOP:
            out.state = S_COMMIT;
        default:  // unknown instruction
            out.state = S_UNKNOWN;
        endcase
    end

    logic _unused_ok = &{funct, rs, rt, rd, shamt, imm};
endmodule
