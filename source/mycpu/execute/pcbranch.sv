`ifndef __PCBRANCH_SV
`define __PCBRANCH_SV


`include "common.svh"
`include "pipes.svh"
`include "../decode/decode.svh"


module pcbranch
	(
        input branch_t branch,
        output u1 branch_condition,
        input word_t srca,srcb,
        input u1 valid
);
    always_comb begin
        branch_condition='0;
        if (valid) begin
            branch_condition=(branch==T_BEQ&&srca==srcb)||(branch==T_BNE&&srca!=srcb)||(branch==T_BGEZ&&~srca[31])||(branch==T_BGTZ&&$signed(srca)>0)||(branch==T_BLEZ&&$signed(srca)<=0)||(branch==T_BLTZ&&srca[31]);
        end
    end

endmodule

`endif
