`include "common.svh"

module pcselect(
    input word_t pc_succ,
    input word_t pc_branch,
    input branch_taken,
    input word_t epc,entrance,
    input u1 is_INTEXC,
    input u1 is_eret,
    output word_t pc_selected
);
    always_comb begin
        pc_selected='0;
        if (is_eret) begin
            pc_selected=epc;
        end else if (is_INTEXC) begin
            pc_selected=entrance;
        end else if (branch_taken) begin
                pc_selected=pc_branch;
        end else begin
                pc_selected=pc_succ;
        end
    end
endmodule