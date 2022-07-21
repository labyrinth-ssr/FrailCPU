`ifndef __WRITEBACK_SV
`define __WRITEBACK_SV

`ifdef VERILATOR
`include "common.svh"
`include "cp0.sv"
`endif 
    module writeback(
        input u1 clk,reset,
        input memory_data_t dataM [1:0],
        output writeback_data_t dataW [1:0],
        input word_t hi_rd,lo_rd,cp0_rd,
        u1 valid_i,valid_j,valid_k
    );

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
            assign dataW[i].valid=dataM[i].valid;
            assign dataW[i].ctl=dataM[i].ctl;
            assign dataW[i].wa=dataM[i].rdst;
        end

        always_comb begin

            for (int i=0; i<2; ++i) begin
                        if (dataM[i].ctl.regwrite) begin
                        dataW[i].wd=dataM[i].alu_out;
                    end else if (dataM[i].ctl.memtoreg) begin
                        dataW[i].wd=dataM[i].rd;
                    end else begin
                        dataW[i].wd='0;
                    end
                end

                if (dataM[valid_i].ctl.cp0toreg) begin
                    dataW[valid_i].wd=cp0_rd;
                end 
                if (dataM[valid_j].ctl.lotoreg) begin
                    dataW[valid_j].wd=lo_rd;
                end 
                if (dataM[valid_k].ctl.hitoreg) begin
                    dataW[valid_k].wd=hi_rd;
                end
                
                
            end
    
        

        
    endmodule

`endif 