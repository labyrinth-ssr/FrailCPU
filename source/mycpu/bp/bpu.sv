`ifndef __BPU_SV
`define __BPU_SV

`include "common.svh"

`ifdef VERILATOR
`include "ras.sv"
`include "bht.sv"
`include "rpct.sv"
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

    logic bht_hit, rpct_hit, f1_jump;
    addr_t bht_pre_pc, ras_pre_pc;
    logic prediction_outcome;
    logic ras_fail;

    always_comb begin : pre_pc_block
        pre_pc = '0;
        if(is_jr_ra_decode) begin
            pre_pc = ras_pre_pc;
        end else if(bht_hit) begin
            pre_pc = bht_pre_pc;
        end else if(rpct_hit) begin
            pre_pc = ras_pre_pc;
        end
    end

    always_comb begin : f1_taken_block
        f1_taken = 1'b0;
        if(rpct_hit && ~ras_fail) begin
            f1_taken = 1'b1;
        end else if (bht_hit) begin
            f1_taken = f1_jump ? 1'b1 : prediction_outcome;
        end
    end

    logic bht_hit_pc, bht_hit_pcp4, rpct_hit_pc, rpce_hit_pcp4;
    assign pos = (bht_hit_pc | rpct_hit_pc) ? 1'b1 : 1'b0;
    assign jr_ra_fail = ras_fail;

    bht bht (
        .clk, .resetn,
        .is_write(is_branch | is_j | is_jal),
        .is_jump_in(is_j | is_jal),
        .branch_pc(f1_pc),
        .executed_branch_pc(exe_pc),
        .dest_pc,
        .is_taken,
        .predict_pc(bht_pre_pc),
        .hit(bht_hit),
        .is_jump_out(f1_jump),
        .dpre(prediction_outcome),
        .hit_pc(bht_hit_pc),
        .hit_pcp4(bht_hit_pcp4)
    );

    ras ras (
        .clk, .resetn,
        .push(is_jal | is_jalr),
        .pop(is_jr_ra_decode | rpct_hit),
        .ret_pc_push(ret_pc),
        .ret_pc_pop(ras_pre_pc),
        .fail(ras_fail)
    );

    rpct rpct (
        .clk, .resetn,
        .is_write(is_jr_ra_exe),
        .pc_check(f1_pc),
        .jrra_pc(exe_pc),
        .hit(rpct_hit),
        .hit_pc(rpct_hit_pc),
        .hit_pcp4(rpce_hit_pcp4)
    );

endmodule


`endif 
