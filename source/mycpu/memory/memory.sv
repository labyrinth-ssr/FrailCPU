`ifndef __MEMORY_SV
`define __MEMORY_SV


`include "common.svh"
`include "pipes.svh"
`include "cp0_pkg.svh"
`ifdef VERILATOR
`include "writedata.sv"
`endif 

module memory
    (
    input execute_data_t [1:0] dataE,
    output execute_data_t [1:0] dataE2,
    output dbus_req_t [1:0]  dreq,
    // input u1 [1:0]  req_finish,
    output u1 excpM
    // input u1 exception
);
word_t [1:0] wd;
strobe_t [1:0] strobe;
// u1 [1:0] store_misalign;
// u1 [1:0] load_misalign;
// word_t paddr[1:0];
u1 uncache;
assign uncache=dataE[1].alu_out[29] || dataE[0].alu_out[29];
// word_t cp0wd;
// pvtrans pvtransd1(
//     .vaddr(dataE[1].alu_out),
//     .paddr(paddr[1])
// );
// pvtrans pvtransd2(
//     .vaddr(dataE[0].alu_out),
//     .paddr(paddr[0])
// );



for (genvar i=0; i<2; ++i) begin
    always_comb begin
        dreq[i] = '0;
        if (dataE[i].ctl.memtoreg) begin
            if (i==1) begin
                dreq[i].valid = '1  ;
            end else begin
                dreq[i].valid = '1  ;
            end
            dreq[i].strobe = '0;
        end else if (dataE[i].ctl.memwrite) begin
            if (i==1) begin
                dreq[i].valid = '1  ;
            end else begin
                dreq[i].valid = '1  ;
            end
            dreq[i].data=wd[i];
            dreq[i].strobe=strobe[i];
        end
        dreq[i].addr = dataE[i].ctl.cache_d? dataE[i].cache_addr :dataE[i].alu_out;
        dreq[i].size=dataE[i].ctl.msize;
    end
    assign dataE2[i].pc=dataE[i].pc;
    assign dataE2[i].rdst=dataE[i].rdst;
//    assign dataE2[i].ctl=dataE[i].ctl;
    assign dataE2[i].alu_out=dataE[i].alu_out;
    assign dataE2[i].valid=dataE[i].valid;
    assign dataE2[i].cp0_ctl=dataE[i].cp0_ctl;
    assign dataE2[i].is_slot=dataE[i].is_slot;
    assign dataE2[i].cp0ra=dataE[i].cp0ra;
    assign dataE2[i].srcb=dataE[i].srcb;
    assign dataE2[i].srca=dataE[i].srca;
    assign dataE2[i].hilo=dataE[i].hilo;
    assign dataE2[i].branch_taken=dataE[i].branch_taken;
    assign dataE2[i].target=dataE[i].target;
end

// assign dataE2[1].valid=dataE[1].valid;
// assign dataE2[0].valid= load_misalign[1]||store_misalign[1]? '0: dataE[1].valid;
    
writedata writedata1(.addr(dataE[1].alu_out[1:0]),._wd(dataE[1].srcb),.msize(dataE[1].ctl.msize),.wd(wd[1]),.strobe(strobe[1]));
writedata writedata2(.addr(dataE[0].alu_out[1:0]),._wd(dataE[0].srcb),.msize(dataE[0].ctl.msize),.wd(wd[0]),.strobe(strobe[0]));     

// assign load_misalign[1]=dataE[1].ctl.memtoreg&&((dataE[1].ctl.msize==MSIZE2&&dataE[1].alu_out[0]!=1'b0)||(dataE[1].ctl.msize==MSIZE4&&dataE[1].alu_out[1:0]!=2'b00));
// assign load_misalign[0]=dataE[0].ctl.memtoreg&&(dataE[0].ctl.msize==MSIZE2&&dataE[0].alu_out[0]!=1'b0)||(dataE[0].ctl.msize==MSIZE4&&dataE[0].alu_out[1:0]!=2'b00);

always_comb begin
        dataE2[1].ctl=dataE[1].ctl;
        dataE2[0].ctl=dataE[0].ctl;
        if (dataE[1].cp0_ctl.ctype==EXCEPTION||dataE[1].cp0_ctl.ctype==ERET) begin
            dataE2[0].ctl.regwrite='0;
            dataE2[0].ctl.memtoreg='0;
            dataE2[0].ctl.lowrite='0;
            dataE2[0].ctl.hiwrite='0;
            dataE2[0].ctl.cp0write='0;
        end
    end

// always_comb begin//都是双端口
//         dataE2[1].cp0_ctl=dataE[1].cp0_ctl;
//         dataE2[0].cp0_ctl=dataE[0].cp0_ctl;
//         if (dataE[1].ctl.memwrite && store_misalign[1]) begin
//             dataE2[1].cp0_ctl.ctype=EXCEPTION;
//             dataE2[1].cp0_ctl.etype.adesD= '1;
//             dataE2[0].cp0_ctl.valid='0;
//             dataE2[1].cp0_ctl.valid='1;
//             dataE2[1].cp0_ctl.vaddr=dataE[1].alu_out;
//         end else if (dataE[0].ctl.memwrite && store_misalign[0]) begin
//             dataE2[0].cp0_ctl.ctype=EXCEPTION;
//             dataE2[0].cp0_ctl.valid='1;
//             dataE2[0].cp0_ctl.etype.adesD='1;
//             dataE2[0].cp0_ctl.vaddr=dataE[0].alu_out;
//         end
//         if (dataE[1].ctl.memtoreg && load_misalign[1]) begin
//             dataE2[1].cp0_ctl.ctype=EXCEPTION;
//             dataE2[1].cp0_ctl.valid='1;
//             dataE2[1].cp0_ctl.etype.adelD= '1;
//             dataE2[1].cp0_ctl.vaddr=dataE[1].alu_out;
//             dataE2[0].cp0_ctl.valid='0;
//         end else if (dataE[0].ctl.memtoreg && load_misalign[0]) begin
//             dataE2[0].cp0_ctl.ctype=EXCEPTION;
//             dataE2[0].cp0_ctl.valid='1;
//             dataE2[0].cp0_ctl.etype.adelD='1;
//             dataE2[0].cp0_ctl.vaddr=dataE[0].alu_out;
//         end
//     end

assign excpM=dataE[0].cp0_ctl.ctype==EXCEPTION||dataE[0].cp0_ctl.ctype==ERET||dataE[1].cp0_ctl.ctype==EXCEPTION||dataE[1].cp0_ctl.ctype==ERET /*|| load_misalign[1]||load_misalign[0]|| store_misalign[1]||store_misalign[0]*/;

endmodule

`endif 