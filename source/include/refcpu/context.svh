`ifndef __REFCPU_CONTEXT_SVH__
`define __REFCPU_CONTEXT_SVH__

`include "defs.svh"

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
        // NOTE: same layout with dbus_req_t
        addr_t   addr;
        msize_t  size;
        strobe_t strobe;
        word_t   data;  // load uses this field to receive data
    } mem;  // used by all load & store operations
} args_t;

// we also guarantee that args will be reset to zeros
// at the beginning of each instruction.
parameter args_t ARGS_RESET = '0;

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

parameter context_t CONTEXT_RESET = '{
    state      : S_FETCH,
    args       : ARGS_RESET,
    cp0        : CP0_RESET,
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
