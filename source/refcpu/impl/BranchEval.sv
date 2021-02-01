`include "refcpu/defs.svh"

module BranchEval (
    input  context_t ctx,
    output context_t out
);
    localparam type offset_t = logic [17:0];

    `FORMAT_ITYPE(opcode, rs, rt, imm, ctx.instr);

    word_t val1, val2;
    assign val1 = ctx.r[rs];
    assign val2 = ctx.r[rt];

    offset_t offset;
    assign offset = {imm, 2'b0};

    addr_t next_pc, link_pc, target_pc, jump_pc, new_pc;
    assign next_pc = ctx.pc + 4;
    assign link_pc = ctx.pc + 8;
    assign target_pc = next_pc + `SIGN_EXTEND(offset, 32);
    assign jump_pc = {ctx.pc[31:28], ctx.instr.payload, 2'b00};

    always_comb begin
        out = ctx;
        out.state = S_BRANCH;

        unique case (opcode)
        OP_BEQ:
            new_pc = val1 == val2 ? target_pc : link_pc;
        OP_BNE:
            new_pc = val1 != val2 ? target_pc : link_pc;
        OP_J, OP_JAL:
            new_pc = jump_pc;

        default:
            // Decode should guarantee that no other instruction
            // enters this state.
            out.state = S_UNKNOWN;
        endcase

        out.args.branch.new_pc = new_pc;

        // link to register
        if (opcode == OP_JAL) begin
            out.target_id = RA;
            out.r[RA] = link_pc;
        end

        // UNPREDICTABLE: branch in delay slot
        if (ctx.delayed)
            out.state = S_UNKNOWN;
    end
endmodule
