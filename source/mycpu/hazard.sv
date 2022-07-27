`ifndef __HAZARD_SV
`define __HAZARD_SV

`ifdef VERILATOR
`include "common.svh"
`endif 

module hazard
(
    output u1 stallF,stallD,flushD,flushE,flushM,stallM,stallE,flushW,stallM2,flushI,flush_que,stallF2,flushF2,stallI,flushM2,stallI_de,
    // input creg_addr_t edst,mdst,wdst,mdst2,
    input branchE,i_wait,d_wait,e_wait,branch_misalign,overflowI,excpM,
    // input creg_addr_t ra1,ra2,ra1E,ra2E,
    // input wrE,wrM,wrW,wrM2,
    // input memwrE,memwrM,memwrM2,
    input excpW,
    input clk
);
// u1 branch_stall,lwstall,multi_stall;
u1 excp_iwait,excp_iwait_nxt,branch_iwait,branch_iwait_nxt,misalign_iwait,misalign_iwait_nxt;
// u64 int_save;

always_ff @(posedge clk) begin
        excp_iwait<=excp_iwait_nxt;
        branch_iwait<=branch_iwait_nxt;
        misalign_iwait<=misalign_iwait_nxt;
end

    always_comb begin
        stallF='0;stallD='0;flushD='0;flushE='0;flushM='0;flushF2='0;flushI='0;flush_que='0;stallF2='0;stallI='0;stallI_de='0;
        stallM='0;stallE='0;excp_iwait_nxt=excp_iwait;stallM2='0;flushW='0;branch_iwait_nxt=branch_iwait;flushM2='0;misalign_iwait_nxt=misalign_iwait;

        if (excpW||excpM) begin
            flushF2='1;
            flushD='1;
            flushI='1;
            flushE='1;
            flushM='1;
            flush_que='1;
            if (excpW) begin
                flushW='1;
                flushM2='1;
            end
        end  else if (e_wait) begin
            stallE='1;flushM='1;stallF='1;stallD='1;stallF2='1;stallI='1;stallI_de='1;
            if (branchE) begin
                flushF2='1;
                flushD='1;
                flushI='1;
                flushE='1;
                flushM='1;
                flush_que='1;
                branch_iwait_nxt=1'b1;

            end
            
            if (d_wait) begin
                stallM='1;flushM='0;
            end 
        end else if (d_wait) begin
            stallM='1;stallE='1;stallF='1;stallF2='1;stallI='1; stallD='1;stallI_de='1;flushM2='1;
        end else if (overflowI&&~branchE) begin
            stallF='1;stallF2='1;stallI='1;stallD='1;
            // if (branchE) begin
            //     flushF2='1;
            //     flushD='1;
            //     flushI='1;
            //     flushE='1;
            //     flushM='1;
            //     flush_que='1;
            // end
        end else if (i_wait) begin
            stallF='1;flushF2='1;
            if (branchE) begin
                branch_iwait_nxt=1'b1;
                flushF2='1;
                flushD='1;
                flushI='1;
                flushE='1;
                flushM='1;
                flush_que='1;
            end 
            if (branch_misalign) begin
                misalign_iwait_nxt=1'b1;
                flushF2='1;flushD='1;
            end
            // multi_stall=multialud && ((wrE&&(edst==ra1||edst==ra2))||(memwrM&& (mdst==ra1||mdst==ra2)) || (memwrM2&& (mdst2==ra1||mdst2==ra2)) || (((ra1!=0&&ra1==mdst && wrM)||(ra2!=0&&ra2==mdst && wrM))) || ((((ra1!=0&&ra1==mdst2 && wrM2)||(ra2!=0&&ra2==mdst2 && wrM2)))));
            // lwstall= (memwrE && (edst==ra1||edst==ra2)) || ((memwrM&& (mdst==ra1||mdst==ra2))) ;

            // if (multi_stall||branch_stall||lwstall) begin
            //     flushD='0;
            //     stallD='1;
            //     flushE='1;
            // end
        end else begin
            // multi_stall=multialud && ((wrE&&(edst==ra1||edst==ra2))||(memwrM&& (mdst==ra1||mdst==ra2)) || (memwrM2&& (mdst2==ra1||mdst2==ra2)) || (((ra1!=0&&ra1==mdst && wrM)||(ra2!=0&&ra2==mdst && wrM))) ||((((ra1!=0&&ra1==mdst2 && wrM2)||(ra2!=0&&ra2==mdst2 && wrM2)))));
            // stallD=lwstall || multi_stall;
            // stallF=stallD;
            // flushE=stallD;

            flushF2=branchE||branch_misalign;
            flushD=branchE||branch_misalign;
            flushI=branchE;
            flushE=branchE;
            flushM=branchE;
            flush_que=branchE;
        end

        if (~stallF&&excp_iwait) begin
            flushF2='1;flushD='1;
            excp_iwait_nxt='0;
        end
        if (~stallF&&branch_iwait) begin
            flushF2='1;flushD='1;
            branch_iwait_nxt='0;
        end
        if (~stallF&&misalign_iwait) begin
            flushF2='1;flushD='1;
            misalign_iwait_nxt='0;
        end
    end


endmodule

`endif 