`ifndef __REFCPU_DEFS_SVH__
`define __REFCPU_DEFS_SVH__

`include "common.svh"
`include "shortcut.svh"

/**
 * CPU states
 */

typedef enum uint {
    S_UNKNOWN = 0,  // see impl/Unknown.sv
    S_COMMIT,
    S_FETCH,
    S_FETCH_ADDR_SENT,
    S_DECODE,
    S_BRANCH_EVAL,
    S_BRANCH,
    S_UNSIGNED_ARITHMETIC,
    S_RTYPE,
    S_EXCEPTION,
    S_ADDR_CHECK,
    S_LOAD,
    S_LOAD_ADDR_SENT,
    S_STORE,
    S_STORE_ADDR_SENT,

    // to record the number of available states
    NUM_CPU_STATES
} cpu_state_t /* verilator public */;

parameter uint LAST_CPU_STATE = NUM_CPU_STATES - 1;

/**
 * instruction fields
 */

typedef i5  shamt_t;
typedef i16 imm_t;
typedef i26 long_imm_t;

// opcode: bit 31~26
typedef enum i6 {
    OP_RTYPE = 6'b000000,
    OP_J     = 6'b000010,
    OP_JAL   = 6'b000011,
    OP_BEQ   = 6'b000100,
    OP_BNE   = 6'b000101,
    OP_ADDIU = 6'b001001,
    OP_SLTI  = 6'b001010,
    OP_SLTIU = 6'b001011,
    OP_ANDI  = 6'b001100,
    OP_ORI   = 6'b001101,
    OP_XORI  = 6'b001110,
    OP_LUI   = 6'b001111,
    OP_LW    = 6'b100011,
    OP_SW    = 6'b101011
} opcode_t /* verilator public */;

// funct (in RType instructions): bit 5~0
typedef enum i6 {
    FN_SLL  = 6'b000000,
    FN_JR   = 6'b001000,
    FN_JALR = 6'b001001,
    FN_ADDU = 6'b100001,
    FN_SUBU = 6'b100011,
    FN_AND  = 6'b100100,
    FN_OR   = 6'b100101,
    FN_XOR  = 6'b100110,
    FN_NOR  = 6'b100111,
    FN_SLT  = 6'b101010,
    FN_SLTU = 6'b101011
} funct_t /* verilator public */;

// general-purpose registers
typedef enum i5 {
    R0, AT, V0, V1, A0, A1, A2, A3,
    T0, T1, T2, T3, T4, T5, T6, T7,
    S0, S1, S2, S3, S4, S5, S6, S7,
    T8, T9, K0, K1, GP, SP, FP, RA
} regid_t;

// MIPS instruction formats
typedef struct packed {
    opcode_t opcode;
    union packed {
        struct packed {
            regid_t  rs;
            regid_t  rt;
            regid_t  rd;
            shamt_t  shamt;
            funct_t  funct;
        } rtype;
        struct packed {
            regid_t  rs;
            regid_t  rt;
            imm_t    imm;
        } itype;
        long_imm_t index;  // J-type
    } payload;
} instr_t;

parameter instr_t INSTR_NOP = 32'b0;

/**
 * exceptions
 */

// exception code
typedef enum i5 {
    EX_INT      = 0,
    EX_MOD      = 1,
    EX_TLBL     = 2,
    EX_TLBS     = 3,
    EX_ADEL     = 4,
    EX_ADES     = 5,
    EX_IBE      = 6,
    EX_DBE      = 7,
    EX_SYS      = 8,
    EX_BP       = 9,
    EX_RI       = 10,
    EX_CPU      = 11,
    EX_OV       = 12,
    EX_TR       = 13,
    EX_FPE      = 15,
    EX_C2E      = 18,
    EX_TLBRI    = 19,
    EX_TLBXI    = 20,
    EX_MDMX     = 22,
    EX_WATCH    = 23,
    EX_MCHECK   = 24,
    EX_THREAD   = 25,
    EX_DSPDIS   = 26,
    EX_CACHEERR = 30
} ecode_t;

/**
 * MIPS CP0 registers
 */

typedef struct packed {
    logic _unused;
} cp0_t;

parameter cp0_t CP0_RESET_VALUE = '{
    _unused: 1'b0
};

/**
 * CPU context
 */

// temporary storage for inter-state arguments
typedef `PACKED_UNION {
    // if one state has argument, add a packed struct in the
    // union with the name of the corresponding state.
    struct packed {
        addr_t new_pc;
    } branch;
    struct packed {
        ecode_t code;
    } exception;
    struct packed {
        addr_t addr;
        msize_t size;
    } mem;  // used by all load & store operations
} args_t;

// we also guarantee that args will be reset to zeros
// at the beginning of each instruction.
parameter args_t ARGS_RESET_VALUE = '0;

typedef struct packed {
    cpu_state_t state;  // CPU state
    args_t args;        // inter-state arguments
    cp0_t cp0;          // CP0 registers
    addr_t pc;          // program counter
    logic delayed;      // currently in delay slot?
    addr_t delayed_pc;  // PC of delayed branches
    regid_t target_id;  // writeback register id, for debugging
    instr_t instr;      // current instruction
    word_t hi, lo;      // HI & LO special registers
    word_t [31:0] r;    // general-purpose registers, r[0] is hardwired to zero
} context_t;

parameter addr_t RESET_PC = 32'hbfc00000;

parameter context_t CONTEXT_RESET_VALUE = '{
    state      : S_FETCH,
    args       : ARGS_RESET_VALUE,
    cp0        : CP0_RESET_VALUE,
    pc         : RESET_PC,
    delayed    : 1'b0,
    delayed_pc : 32'b0,
    target_id  : R0,
    instr      : INSTR_NOP,
    hi         : 32'b0,
    lo         : 32'b0,
    r          : {32{32'b0}}
};

`endif
