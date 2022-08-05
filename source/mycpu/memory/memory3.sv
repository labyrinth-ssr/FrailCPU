`ifndef __M2_SV
`define __M2_SV


`include "common.svh"
`include "pipes.svh"
`ifdef VERILATOR
`include "readdata.sv"
`endif


module memory3
    (
    input clk,
    input execute_data_t [1:0] dataE,
    output memory_data_t [1:0] dataM,
    input  dbus_resp_t dresp,
    input dbus_req_t [1:0] dreq,
    input logic resetn
);
u1 uncache;
assign uncache=dreq[1].addr[29] || dreq[0].addr[29];
// u64 wd;
// u8 strobe;
// u1 load_misalign;
word_t data1_save;
u1 data1_saved;
u1 req2_valid_delay;
always_ff @(posedge clk) begin
    if (~resetn) begin
        req2_valid_delay<='0;
    end else begin
        req2_valid_delay<=dreq[0].valid;
    end
end
// always_ff @(posedge clk) begin
//     if (resetn) begin
//         if ((req2_valid_delay&&~dresp[0].data_ok) && dresp[1].data_ok) begin
//             data1_save<=dresp[1].data;
//             data1_saved<='1;
//         end
//         else if (dresp[0].data_ok) begin
//             data1_save<='0;
//             data1_saved<='0;
//         end
//     end
//     else begin
//         data1_save<='0;
//         data1_saved<='0;
//     end   
// end

// word_t data2_save;
// u1 data2_saved;
// //cache hit？
// u1 req1_valid_delay;
// always_ff @(posedge clk) begin
//     if (~resetn) begin
//         req1_valid_delay<='0;
//     end else begin
//         req1_valid_delay<=dreq[1].valid;
//     end
// end
// always_ff @(posedge clk) begin
//     if (resetn) begin
//         if ((req1_valid_delay&&~dresp[1].data_ok) && dresp[0].data_ok) begin
//             data2_save<=dresp[0].data;
//             data2_saved<='1;
//         end
//         else if (dresp[1].data_ok) begin
//             data2_save<='0;
//             data2_saved<='0;
//         end
//     end
//     else begin
//         data2_save<='0;
//         data2_saved<='0;
//     end   
// end
    

readdata readdata1(._rd(  dresp.data[31:0]),.rd(dataM[1].rd),.addr(dataE[1].alu_out[1:0]),.msize(dataE[1].ctl.msize),.mem_unsigned(~dataE[1].ctl.memsext));
readdata readdata2(._rd(  dresp.data[63:32]),.rd(dataM[0].rd),.addr(dataE[0].alu_out[1:0]),.msize(dataE[0].ctl.msize),.mem_unsigned(~dataE[0].ctl.memsext));

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
    assign dataM[i].srca=dataE[i].srca;
    assign dataM[i].hilo=dataE[i].hilo;
end

endmodule

`endif 