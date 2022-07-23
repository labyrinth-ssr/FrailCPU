

`include "common.svh"
`include "pcselect.sv"
`include "bpu.sv"

module fetchInstr(
    output fetch_data_t dataF,
    input word_t executed_branch,
    
);
    u1 b_taken;
    pcselect pcselect_inst(
        .pc,
        .pc_nxt,
        .branch_pc,
        .branch_taken(b_taken)
    );

    bpu bpu_inst(
        .taken(b_taken),
        .resolved_branch,
        .executed_branch,
        .except_pc
    );

    assign ireq.addr=pc;
    assign ireq.valid='1;

    assign dataF.instr=iresp.data;
    
endmodule
