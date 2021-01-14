`ifndef __REFCPU_DEFS_SVH__
`define __REFCPU_DEFS_SVH__

`include "Common.svh"

typedef enum uint {
    UNKNOWN = 0,
    COMMIT,
    FETCH,
    DECODE,

    // to record the number of available states
    NUM_STATES
} state_t;

parameter uint LAST_STATE = NUM_STATES - 1;

typedef struct packed {
    state_t state;      // CPU state
    addr_t pc;          // program counter
    logic is_delayed;   // currently in delay slot?
    addr_t delayed_pc;  // PC for delayed branches
    word_t [31:0] r;    // architectural registers
    word_t [7:0] t;     // temporary registers
} context_t;

parameter context_t RESET_CONTEXT = {
    FETCH,        // state
    32'b0,        // pc
    1'b0,         // is_delayed
    32'b0,        // delayed_pc
    {32{32'b0}},  // r[31:0]
    {8{32'b0}}    // t[7:0]
};

// instruction fields
typedef logic [5 :0] funct_t;
typedef logic [4 :0] regid_t;
typedef logic [15:0] imm_t;

// opcode: bit 31~26
typedef enum logic [5:0] {
    OP_NOP
} opcode_t;

`endif