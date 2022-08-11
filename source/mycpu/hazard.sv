`ifndef __HAZARD_SV
`define __HAZARD_SV

`include "common.svh"

module hazard
(
    output u1 stallF,stallF2,flushF2,stallD,flushD,stallI,stallI_de,flushI,flush_que,stallE,flushE,stallM,flushM,stallM2,flushM2,flushW,flushM3,pred_flush_que,
    input u1 branchM,i_wait,d_wait,e_wait,overflowI,jrI,waitM,
    input u1 excpW,excpM,
    input u1 clk,reset
);
// u1 branch_stall,lwstall,multi_stall;
u1 excp_iwait,excp_iwait_nxt,branch_iwait,branch_iwait_nxt,branchI_iwait,branchI_iwait_nxt;
// u64 int_save;
//E_WAIT
always_ff @(posedge clk) begin
    if (reset) begin
        {excp_iwait,branch_iwait}<='0;
    end else begin
        excp_iwait<=excp_iwait_nxt;
        branch_iwait<=branch_iwait_nxt;
        branchI_iwait<=branchI_iwait_nxt;
        // misalign_iwait<=misalign_iwait_nxt;        
    end
end

    always_comb begin
        stallF='0;stallD='0;flushD='0;flushE='0;flushM='0;flushF2='0;flushI='0;flush_que='0;stallF2='0;stallI='0;stallI_de='0;branchI_iwait_nxt=branchI_iwait;
        stallM='0;stallE='0;excp_iwait_nxt=excp_iwait;stallM2='0;flushW='0;branch_iwait_nxt=branch_iwait;flushM2='0;flushM3='0;
        pred_flush_que='0;
        if (excpW) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            flushE='1;
            flushM='1;
            flush_que='1;
            flushM3='1;
            flushM2='1;
            flushW='1;
            if (i_wait) begin
                excp_iwait_nxt=1'b1;
                stallF ='1;
            end
        end else if (d_wait||waitM) begin
            stallF='1;stallF2='1;stallD='1;stallI='1;stallI_de='1;stallE='1;stallM='1; stallM2='1;flushM3='1;
        end else if (excpM) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            flushE='1;
            flushM='1;
            flush_que='1;
            if (i_wait) begin
                excp_iwait_nxt=1'b1;
                stallF ='1;
            end
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
        end else if (jrI) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            pred_flush_que='1;
            if (i_wait) begin
                branchI_iwait_nxt=1'b1;
                stallF ='1;
            end
        end else if (overflowI) begin
            stallF='1;stallF2='1;stallI='1;stallD='1;
        end /*else if (branchI) begin
            flushF2='1;
            flushD='1;
            if (i_wait) begin
                stallF='1;
                branchI_iwait_nxt=1'b1;
            end
        end */else if (i_wait) begin
            stallF='1;flushF2='1;
        end
        if (~stallF&&excp_iwait) begin
            flushF2='1;flushD='1;
            excp_iwait_nxt='0;
        end
        if (~stallF&&branch_iwait) begin
            flushF2='1;flushD='1;
            branch_iwait_nxt='0;
        end
        if (~stallF&&branchI_iwait) begin
            flushF2='1;flushD='1;
            branchI_iwait_nxt='0;
        end
    end
endmodule

`endif 