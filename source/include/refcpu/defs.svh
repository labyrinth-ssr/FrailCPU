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

// opcode: bit 31~26
typedef enum i6 {
    OP_RTYPE = 6'b000000,
    OP_BEQ   = 6'b000100,
    OP_BNE   = 6'b000101,
    OP_ADDIU = 6'b001001
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

typedef struct packed {
    cpu_state_t state;  // CPU state
    cp0_t cp0;          // CP0 registers
    addr_t pc;          // program counter
    addr_t next_pc;     // PC + 4, hardwired
    logic delayed;      // currently in delay slot?
    addr_t delayed_pc;  // PC of delayed branches
    word_t hi, lo;      // HI & LO special registers
    word_t [7:0] t;     // temporary registers
    word_t [31:0] r;    // general-purpose registers, r[0] is hardwired to zero
} context_t;

parameter context_t CONTEXT_RESET_VALUE = {
    S_FETCH,          // state
    CP0_RESET_VALUE,  // cp0
    32'hbfc00000,     // pc
    32'hbfc00004,     // next_pc
    1'b0,             // is_delayed
    32'b0,            // delayed_pc
    {2{32'b0}},       // hi, lo
    {8{32'b0}},       // [7:0] t
    {32{32'b0}}       // [31:0] r
};

`endif
