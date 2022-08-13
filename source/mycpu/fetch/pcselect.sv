`include "common.svh"

module pcselect(
    input word_t pc_succ,
    input word_t pc_branch,/*misaligned_pc,*/
    input branch_taken,/*branch_misalign,*/
    input word_t epc,
    input u1 is_INTEXC,
    input u1 is_eret,
    input word_t pre_pc,
    input u1 pred_taken,
    input u1 issue_taken,
    output word_t pc_selected,
    input u1 zero_prej,
    input word_t entrance,
    input u1 icache,
    input word_t icache_addr
    // output u1 forward_pc_taken
    // input u1 is_tlb_refill
);

    // assign forward_pc_taken=is_eret|is_INTEXC|icache|branch_taken|issue
    always_comb begin
        pc_selected='0;
        if (is_eret) begin
            pc_selected=epc;
        end /*else if (is_tlb_refill) begin
            pc_selected=32'hbfc00200;
        end */else if (is_INTEXC) begin
            pc_selected=entrance;
        end else if (icache) begin
            pc_selected=icache_addr;
        end else if (branch_taken) begin
            pc_selected=pc_branch;
        end else if (issue_taken) begin
            pc_selected=pre_pc;
        end else if (zero_prej) begin
            pc_selected=pc_succ-4;
        end else if (pred_taken) begin
            pc_selected=pre_pc;
        end else begin
            pc_selected=pc_succ;
        end
    end
endmodule