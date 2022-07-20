`ifndef BRANCH_RESOLVE_SV
`define BRANCH_RESOLVE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 
    module harzard(
        input fetch_data_t dataF2,
        output u32 j_pc,
        output u1 j
    );

    

    endmodule

`endif