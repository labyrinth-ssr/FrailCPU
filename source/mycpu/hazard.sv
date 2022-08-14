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
u1 fihazrd,fihazrd_nxt;

always_ff @(posedge clk) begin
    if (reset) begin
        fihazrd<='0;
    end else begin
        fihazrd<=fihazrd_nxt;
    end
end

// u1 wait_m;
// assign wait_m = d_wait | waitM ;


// assign stallF = wait_m | e_wait | overflowI | i_wait;
// assign stallF2 = wait_m | e_wait | overflowI;
// assign stallD = wait_m | e_wait | overflowI;
// assign stallI = wait_m | e_wait | overflowI;
// assign stallI_de = wait_m | e_wait;
// assign stallM = wait_m;
// assign stallM2 = wait_m;

// assign flushF2 = excpW | (~(overflowI&i_wait) &fihazrd)  | (~wait_m & (excpM| branchM | (~e_wait & (jrI | i_wait))  ));
// assign flushD =  excpW | (~(overflowI&i_wait) &fihazrd)  | (~wait_m & (excpM| branchM | (~e_wait & jrI )  ));
// assign flushI =  excpW | (~wait_m & (excpM| branchM | (~e_wait & jrI )  ));
// assign flushE =  excpW | (~wait_m & (excpM| branchM ));
// assign flushM =  excpW | 

// assign flush_que= excpW | excpM | branchM;


    always_comb begin
        stallF='0;stallD='0;flushD='0;flushE='0;flushM='0;flushF2='0;flushI='0;flush_que='0;stallF2='0;stallI='0;stallI_de='0;
        stallM='0;stallE='0;fihazrd_nxt=fihazrd;stallM2='0;flushW='0;flushM2='0;flushM3='0;
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
                fihazrd_nxt=1'b1;
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
                fihazrd_nxt=1'b1;
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
                fihazrd_nxt=1'b1;
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
                fihazrd_nxt=1'b1;
                stallF ='1;
            end
        end else if (overflowI) begin
            stallF='1;stallF2='1;stallI='1;stallD='1;
        end else if (i_wait) begin
            stallF='1;flushF2='1;
        end
        
        if (~stallF&&fihazrd) begin
            flushF2='1;
            fihazrd_nxt='0;
        end
    end
endmodule

`endif 