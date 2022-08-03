`include "common.svh"

module pcselect(
    input word_t pc_succ,
    input word_t pc_branch,/*misaligned_pc,*/
    input branch_taken,/*branch_misalign,*/
    input word_t epc,entrance,
    input u1 is_INTEXC,
    input u1 is_eret,
    input word_t pre_pc,
    input u1 pred_taken,decode_taken,
    output word_t pc_selected,
    input u1 select_slot,
    input word_t slot_pc
);
    always_comb begin
        pc_selected='0;
        if (is_eret) begin
            pc_selected=epc;
        end else if (is_INTEXC) begin
            pc_selected=entrance;
        end else if (branch_taken) begin
            pc_selected=pc_branch;
        end else if (select_slot) begin
            pc_selected=slot_pc;
        end else if (decode_taken) begin
            pc_selected=pre_pc;
        end else if (pred_taken) begin
            pc_selected=pre_pc;
        end else begin
            pc_selected=pc_succ;
        end
    end
endmodule