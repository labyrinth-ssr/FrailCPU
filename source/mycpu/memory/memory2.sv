`ifndef __M2_SV
`define __M2_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`include "memory/readdata.sv"
`endif 

module memory2
    (
    input execute_data_t dataE[1:0],
    output memory_data_t dataM[1:0],
    input  dbus_resp_t dresp[1:0]
);
u64 wd;
u8 strobe;
u1 load_misalign;


readdata readdata1(._rd(dresp[1].data),.rd(dataM[1].rd),.addr(dataE[1].alu_out[1:0]),.msize(dataE[1].ctl.msize),.mem_unsigned(~dataE[1].ctl.memsext));
readdata readdata2(._rd(dresp[0].data),.rd(dataM[0].rd),.addr(dataE[0].alu_out[1:0]),.msize(dataE[0].ctl.msize),.mem_unsigned(~dataE[0].ctl.memsext));

    // always_comb begin
    //     dataM.cp0_ctl=dataE.cp0_ctl;
    //     if (dataE.ctl.memRw==2'b01&& load_misalign) begin
    //         dataM.cp0_ctl.code=4'h4;
    //         dataM.cp0_ctl.ctype=EXCEPTION;
    //     end
    // end

for (genvar i=0; i<2; ++i) begin
    assign dataM[i].pc=dataE[i].pc;
    assign dataM[i].rdst=dataE[i].rdst;
    assign dataM[i].alu_out=dataE[i].alu_out;
    assign dataM[i].valid=dataE[i].valid;
    assign dataM[i].cp0_ctl=dataE[i].cp0_ctl;
    assign dataM[i].is_slot=dataE[i].is_slot;
    assign dataM[i].ctl=dataE[i].ctl;
    assign dataM[i].cp0ra=dataE[i].cp0ra;
    assign dataM[i].srcb=dataE[i].srcb;
end

endmodule

`endif 