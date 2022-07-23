`ifndef BRANCH_RESOLVE_SV
`define BRANCH_RESOLVE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 
    module branch_resolve(
        input fetch_data_t dataF2[1:0],
        output u32 j_pc,
        output u1 j
    );
    always_comb begin
        {j,j_pc}='0;
        if (dataF2[1].raw_instr[31:26]==F6_JAL||dataF2[1].raw_instr[31:26]==F6_J) begin
            j_pc={dataF2[1].pc[31:28],dataF2[1].raw_instr[25:0],2'b00};
            j='1;
        end
        else if (dataF2[0].raw_instr[31:26]==F6_JAL||dataF2[0].raw_instr[31:26]==F6_J) begin
            j_pc={dataF2[0].pc[31:28],dataF2[0].raw_instr[25:0],2'b00};
            j='1;
        end
    end

    endmodule

`endif