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
            branch_condition=(branch==T_BEQ&&srca==srcb)||(branch==T_BNE&&srca!=srcb)||(branch==T_BGEZ&&$signed(srca)>=0)||(branch==T_BGTZ&&$signed(srca)>0)||(branch==T_BLEZ&&$signed(srca)<=0)||(branch==T_BLTZ&&$signed(srca)<0);
        end
    end

endmodule

`endif
