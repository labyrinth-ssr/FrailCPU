`ifndef __WRITEBACK_SV
`define __WRITEBACK_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "pipeline/writeback/cp0.sv"
`endif 
    module writeback(
        input u1 clk,reset,
        input memory_data_t dataM [1:0],
        output writeback_data_t dataW [1:0],
    );

        for (genvar i=0; i<2; ++i) begin
            always_comb begin
                if (dataM[i].ctl.cp0toreg) begin
                    dataW[i].wd=dataM[i].cp0_rd;
                end else if (dataM[i].ctl.memtoreg) begin
                    dataW[i].wd=dataM[i].rd;
                end else if (dataM[i].ctl.lotoreg) begin
                    dataW[i].wd=dataM[i].lo_rd;
                end else if (dataM[i].ctl.hitoreg) begin
                    dataW[i].wd=dataM[i].hi_rd;
                end else if (dataM[i].ctl.regwrite) begin
                    dataW[i].wd=dataM[i].alu_out;
                end else begin
                    dataW[i].wd='0;
                end
            end
        assign dataW[i].valid=dataM[i].valid;
        end
        
    endmodule

`endif 