`ifndef __DECODE_SV
`define __DECODE_SV
`ifdef VERILATOR
`include "common.svh"
`include "decoder.sv"
`else

`endif

module decode(
    input fetch_data_t dataF2 [1:0],
    output decode_data_t dataD [1:0],
    output branch_misalign,
    input word_t rd1[1:0],
    input word_t rd2[1:0]
);
    decode_data_t dataD0;
    decoder decoder_inst1(
        .instr(dataF2[1].raw_instr),
        .cp0_ctl_old(dataF2[1].cp0_ctl),
        .cp0_ctl(dataD[1].cp0_ctl),
        .ctl(dataD[1].ctl),
        .srcrega(dataD[1].ra1), 
        .srcregb(dataD[1].ra2), 
        .destreg(dataD[1].rdst)
    );
    decoder decoder_inst2(
        .instr(dataF2[0].raw_instr),
        .ctl(dataD0.ctl),
        .cp0_ctl_old(dataF2[0].cp0_ctl),
        .cp0_ctl(dataD[1].cp0_ctl),
        .srcrega(dataD0.ra1), 
        .srcregb(dataD0.ra2), 
        .destreg(dataD0.rdst)
    );
    assign dataD[1].raw_instr=dataF2[1].raw_instr;
    assign dataD[1].valid=dataF2[1].valid;
    assign dataD[1].pc=dataF2[1].pc;
    assign dataD[1].imm=dataF2[1].raw_instr[15:0];
    assign dataD[0].imm=dataF2[0].raw_instr[15:0];
    always_comb begin
        dataD[0]='0;
        if (~dataD0.ctl.jump&&~dataD0.ctl.branch) begin
            dataD[0]=dataD0;
            dataD[0].raw_instr=dataF2[0].raw_instr;
            dataD[0].valid=dataF2[0].valid;
            dataD[0].pc=dataF2[0].pc;
        end 
    end
    assign dataD[0].is_slot=dataD[1].ctl.jump||dataD[1].ctl.branch;
    assign branch_misalign=dataD0.ctl.jump||dataD0.ctl.branch;
    assign dataD[1].cp0ra=dataD[1].ctl.cp0write? {dataF2[1].raw_instr[15:11],dataF2[1].raw_instr[2:0]}:'0;
    assign dataD[0].cp0ra=dataD0.ctl.cp0write? {dataF2[0].raw_instr[15:11],dataF2[0].raw_instr[2:0]}:'0;
    for (genvar i=0; i<2; ++i) begin
        assign dataD[i].rd1=rd1[i];
        assign dataD[i].rd2=rd2[i];
    end

    
endmodule

`endif