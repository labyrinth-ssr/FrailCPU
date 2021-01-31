`ifndef __REFCPU_SHORTCUT_SVH__
`define __REFCPU_SHORTCUT_SVH__

`define SIGN_EXTEND(imm) \
    {{(31 - $high(imm)){imm[$high(imm)]}}, imm}
`define ZERO_EXTEND(imm) \
    {{(31 - $high(imm)){1'b0}}, imm}

`define FORMAT_ITYPE(opcode, rs, rt, imm, instr) \
    opcode_t opcode; \
    regid_t rs, rt; \
    imm_t imm; \
    assign {opcode, rs, rt, imm} = instr;
`define FORMAT_RTYPE(rs, rt, rd, shamt, funct, instr) \
    regid_t rs, rt, rd; \
    shamt_t shamt; \
    funct_t funct; \
    assign {rs, rt, rd, shamt, funct} = instr.payload;

`endif
