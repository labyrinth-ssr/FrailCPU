`ifndef __M2_SV
`define __M2_SV

`ifdef VERILATOR
`include "include/common.sv"
`include "include/pipes.sv"
`include "pipeline/memory/readdata.sv"
`endif 

module m2
    import common::*;
	import pipes::*;(
    input execute_data_t dataE[1:0],
    output memory_data_t dataM[1:0],
    input  dbus_resp_t dresp
);
u64 wd;
u8 strobe;
u1 load_misalign;

readdata readdata(._rd(dresp.data),.rd(dataM.rd),.addr(dataE.alu_out[2:0]),.msize(dataE.ctl.msize),.mem_unsigned(~dataE.ctl.memsext),.load_misalign);

    // always_comb begin
    //     dataM.cp0_ctl=dataE.cp0_ctl;
    //     if (dataE.ctl.memRw==2'b01&& load_misalign) begin
    //         dataM.cp0_ctl.code=4'h4;
    //         dataM.cp0_ctl.ctype=EXCEPTION;
    //     end
    // end

for (genvar i=0; i<2; ++i) begin
    assign dataM[i].pc=dataE[i].pc;
    assign dataM[i].dst=dataE[i].dst;
    assign dataM[i].sextimm=dataE[i].sextimm;
    assign dataM[i].alu_out=dataE[i].alu_out;
    assign dataM[i].int_type=dataE[i].int_type;
    assign dataM[i].valid=dataE[i].valid;
    assign dataM[i].cp0_ctl=dataE[i].cp0_ctl;
    assign dataM[i].is_slot=dataE[i].is_slot;
    assign dataM[i].ctl=dataE[i].ctl;
    assign dataM[i].cp0ra=dataE[i].cp0ra;
end

endmodule

`endif 