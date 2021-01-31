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
    OP_BEQ   = 6'b000100,
    OP_BNE   = 6'b000101,
    OP_ADDIU = 6'b001001,
    OP_ANDI  = 6'b001100,
    OP_ORI   = 6'b001101,
    OP_XORI  = 6'b001110,
    OP_LUI   = 6'b001111
} opcode_t /* verilator public */;

// funct (in RType instructions): bit 5~0
typedef enum i6 {
    FN_SLL = 6'b000000
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
        struct packed {
            long_imm_t imm;
        } jtype;
    } payload;
} instr_t;

parameter instr_t INSTR_NOP = 32'b0;

/**
 * MIPS CP0 registers
 */

typedef struct packed {
    logic _unused;
} cp0_t;

parameter cp0_t CP0_RESET_VALUE = {
    1'b0  // _unused
};

/**
 * CPU context
 */

/**
 * temporary storage for inter-state arguments
 *
 * NOTE: Vivado does not support that members of a packed union
 * have different sizes. Therefore, we have to use struct instead
 * of union in Vivado.
 */
`ifdef VERILATOR
typedef union packed {
`else
typedef struct packed {
`endif

    // if one state has argument, add a packed struct in the
    // union with the name of the corresponding state.
    struct packed {
        regid_t target_id;
    } commit;
    struct packed {
        addr_t new_pc;
    } branch;
} args_t;

// we also guarantee that args will be reset to zeros
// at the beginning of each instruction.
parameter args_t ARGS_RESET_VALUE = '0;

typedef struct packed {
    cpu_state_t state;  // CPU state
    args_t args;        // inter-state arguments
    cp0_t cp0;          // CP0 registers
    addr_t pc;          // program counter
    addr_t next_pc;     // PC + 4, hardwired
    logic delayed;      // currently in delay slot?
    addr_t delayed_pc;  // PC of delayed branches
    instr_t instr;      // current instruction
    word_t hi, lo;      // HI & LO special registers
    word_t [31:0] r;    // general-purpose registers, r[0] is hardwired to zero
} context_t;

parameter addr_t RESET_PC = 32'hbfc00000;

parameter context_t CONTEXT_RESET_VALUE = {
    S_FETCH,           // state
    ARGS_RESET_VALUE,  // args
    CP0_RESET_VALUE,   // cp0
    RESET_PC,          // pc
    RESET_PC + 4,      // next_pc
    1'b0,              // is_delayed
    32'b0,             // delayed_pc
    INSTR_NOP,         // instr
    {2{32'b0}},        // hi, lo
    {32{32'b0}}        // [31:0] r
};

`endif
