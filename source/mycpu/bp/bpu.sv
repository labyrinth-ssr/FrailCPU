`ifndef __BPU_SV
`define __BPU_SV

`include "common.svh"

`ifdef VERILATOR
`include "bht.sv"

`endif 

module bpu #(
    parameter int COUNTER_BITS = 2
) (
    input logic clk, resetn,

    input addr_t f1_pc,// f1
    output logic f1_taken, pos,
    output addr_t pre_pc,

    input logic is_jr_ra_decode,// decode (jump do not need pre)
    output logic jr_ra_fail,
    // output addr_t decode_ret_pc,

    input addr_t exe_pc, dest_pc, ret_pc,// exe
    // ret_pc for jal, jalr
    input logic is_branch, is_j, is_jal, is_jalr, is_jr_ra_exe,
    input logic is_taken
);

    logic bht_hit;
    addr_t bht_pre_pc;
    logic prediction_outcome;

    always_comb begin : pre_pc_block
        pre_pc = '0;
        if(bht_hit) begin
            pre_pc = bht_pre_pc;
        end
    end

    always_comb begin : f1_taken_block
        f1_taken = 1'b0;
        if (bht_hit) begin
            f1_taken = prediction_outcome;
        end
    end

    logic bht_hit_pc, bht_hit_pcp4;
    assign pos = bht_hit_pc;
    assign jr_ra_fail = 1'b1;

    bht bht (
        .clk, .resetn,
        .is_write(is_branch | is_j | is_jal),
        .branch_pc(f1_pc),
        .executed_branch_pc(exe_pc),
        .dest_pc,
        .is_taken,
        .is_jump_in(is_j | is_jal),
        .predict_pc(bht_pre_pc),
        .hit(bht_hit),
        .dpre(prediction_outcome),
        .hit_pc(bht_hit_pc),
        .hit_pcp4(bht_hit_pcp4)
    );

endmodule


`endif 
