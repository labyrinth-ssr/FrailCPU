`ifndef __HAZARD_SV
`define __HAZARD_SV

`include "common.svh"

module hazard
(
    output u1 stallF,stallF2,flushF2,stallD,flushD,stallI,stallI_de,flushI,flush_que,stallE,flushE,stallM,flushM,stallM2,flushM2,flushW,
    input u1 branchM,i_wait,d_wait,e_wait,overflowI,/*branch_misalign,*/
    input u1 excpW,excpM,
    input u1 clk,reset
);
// u1 branch_stall,lwstall,multi_stall;
u1 excp_iwait,excp_iwait_nxt,branch_iwait,branch_iwait_nxt/*,misalign_iwait,misalign_iwait_nxt*/;
// u64 int_save;

always_ff @(posedge clk) begin
    if (reset) begin
        {excp_iwait,branch_iwait}<='0;
    end else begin
        excp_iwait<=excp_iwait_nxt;
        branch_iwait<=branch_iwait_nxt;
        // misalign_iwait<=misalign_iwait_nxt;        
    end
end

    always_comb begin
        stallF='0;stallD='0;flushD='0;flushE='0;flushM='0;flushF2='0;flushI='0;flush_que='0;stallF2='0;stallI='0;stallI_de='0;
        stallM='0;stallE='0;excp_iwait_nxt=excp_iwait;stallM2='0;flushW='0;branch_iwait_nxt=branch_iwait;flushM2='0;/*misalign_iwait_nxt=misalign_iwait;*/
        if (excpW||excpM) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            flushE='1;
            flushM='1;
            flush_que='1;
            if (excpW) begin
                flushM2='1;
                flushW='1;
            end
            if (i_wait) begin
                excp_iwait_nxt=1'b1;
                stallF ='1;
            end
        end else if (d_wait) begin
            stallF='1;stallF2='1;stallD='1;stallI='1;stallE='1;stallI_de='1;stallM='1; flushM2='1;
        end else if (branchM) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            flushE='1;
            flushM='1;
            flush_que='1;
            if (i_wait) begin
                branch_iwait_nxt=1'b1;
                stallF ='1;
            end
        end else if (e_wait) begin
            stallF='1;stallF2='1;stallD='1;stallI='1;stallI_de='1;stallE='1;flushM='1;
        end else if (overflowI) begin
            stallF='1;stallF2='1;stallI='1;stallD='1;
        end /*else if (branch_misalign) begin
            flushF2='1;
            flushD='1;
            if (i_wait) begin
                stallF='1;
                misalign_iwait_nxt=1'b1;
            end
        end*/else if (i_wait) begin
            stallF='1;flushF2='1;
        end
        if (~stallF&&excp_iwait) begin
            flushF2='1;flushD='1;
            excp_iwait_nxt='0;
        end
        if (~(i_wait||e_wait)&&branch_iwait) begin
            flushF2='1;flushD='1;
            branch_iwait_nxt='0;
        end
        // if (~i_wait&&misalign_iwait) begin
        //     flushF2='1;flushD='1;
        //     misalign_iwait_nxt='0;
        // end
    end


endmodule

`endif 