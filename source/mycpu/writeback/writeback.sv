`ifndef __WRITEBACK_SV
`define __WRITEBACK_SV

`include "common.svh"
    module writeback(
        // input u1 clk,reset,
        input memory_data_t [1:0] dataM ,
        output writeback_data_t [1:0] dataW ,
        input word_t hi_rd,lo_rd,cp0_rd
        // input u1 valid_i,valid_j,valid_k
    );

    word_t pc[1:0]/* verilator public_flat_rd */,wd[1:0]/* verilator public_flat_rd */;
    u1 wen[1:0]/* verilator public_flat_rd */;
    creg_addr_t wa[1:0]/* verilator public_flat_rd */;

    for (genvar i=0; i<2; ++i) begin
        assign pc[i]=dataW[i].pc;
        assign wa[i]=dataW[i].wa;
        assign wd[i]=dataW[i].wd;
        assign wen[i]=dataW[i].valid;
    end
        for (genvar i=0; i<2; ++i) begin
            // always_comb begin

            //     if (dataM[i].ctl.cp0toreg) begin
            //         dataW[i].wd=dataM[i].cp0_rd;
            //     end else if (dataM[i].ctl.memtoreg) begin
            //         dataW[i].wd=dataM[i].rd;
            //     end else if (dataM[i].ctl.lotoreg) begin
            //         dataW[i].wd=dataM[i].lo_rd;
            //     end else if (dataM[i].ctl.hitoreg) begin
            //         dataW[i].wd=dataM[i].hi_rd;
            //     end else if (dataM[i].ctl.regwrite) begin
            //         dataW[i].wd=dataM[i].alu_out;
            //     end else begin
            //         dataW[i].wd='0;
            //     end
            // end
            assign dataW[i].valid=(dataM[i].cp0_ctl.ctype==EXCEPTION || dataM[i].cp0_ctl.ctype==ERET) ? '0: dataM[i].ctl.regwrite&&dataM[i].valid;
            assign dataW[i].ctl=dataM[i].ctl;
            assign dataW[i].wa=dataM[i].rdst;
            assign dataW[i].pc=dataM[i].pc;
        end

        always_comb begin

            for (int i=0; i<2; ++i) begin
                dataW[i].wd='0;
                if (dataM[i].ctl.memtoreg) begin
                    dataW[i].wd=dataM[i].rd;
                end else if (dataM[i].ctl.regwrite) begin
                    dataW[i].wd=dataM[i].alu_out;
                end else begin
                    dataW[i].wd='0;
                end

                if (dataM[i].ctl.cp0toreg) begin
                    dataW[i].wd=cp0_rd;
                end 
                if (dataM[i].ctl.lotoreg) begin
                    dataW[i].wd=lo_rd;
                end 
                if (dataM[i].ctl.hitoreg) begin
                    dataW[i].wd=hi_rd;
                end
            end
            //不需要valid位

                
                
                
        end
    
        

        
    endmodule

`endif 