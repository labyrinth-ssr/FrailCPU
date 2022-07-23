`ifndef __MEMORY_SV
`define __MEMORY_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`include "memory/writedata.sv"
`endif 

module memory
    (
    input execute_data_t dataE[1:0],
    output execute_data_t dataE2[1:0],
    output dbus_req_t  dreq[1:0],
    input u1 [1:0]  req_finish
    // input u1 exception
);
word_t wd[1:0];
strobe_t strobe[1:0];
u1 store_misalign[1:0];
u1 load_misalign[1:0];
word_t paddr[1:0];
// word_t cp0wd;
pvtrans pvtransd1(
    .vaddr(dataE[1].alu_out),
    .paddr(paddr[1])
);
pvtrans pvtransd2(
    .vaddr(dataE[0].alu_out),
    .paddr(paddr[0])
);
for (genvar i=0; i<2; ++i) begin
    always_comb begin
        dreq[i] = '0;
        if (dataE[i].ctl.memtoreg) begin
            dreq[i].valid = dataE[i].cp0_ctl.valid|| load_misalign[i]||req_finish[i] ? '0: '1;
            dreq[i].strobe = '0;
            dreq[i].addr = paddr[i];
            dreq[i].size=dataE[i].ctl.msize;
        end else if (dataE[i].ctl.memwrite) begin
            dreq[i].valid =  dataE[i].cp0_ctl.valid||store_misalign[i]||req_finish[i] ? '0:'1;
            dreq[i].addr = paddr[i];
            dreq[i].data=wd[i];
            dreq[i].strobe=strobe[i];
            dreq[i].size=dataE[i].ctl.msize;
        end
    end
    // always_comb begin
    //     dataE2[i].cp0_ctl=dataE[i].cp0_ctl;
    //     if (dataE.ctl.memwrite && store_misalign) begin
    //         dataE2[i].cp0_ctl.ctype=EXCEPTION;
    //         dataE2[i].cp0_ctl.code=EXCCODE_ADES;
    //     end else if (dataE.ctl.memtoreg && load_misalign) begin
    //         dataE2[i].cp0_ctl.ctype=EXCEPTION;
    //         dataE2[i].cp0_ctl.code=EXCCODE_ADEL;
    //     end
    // end
    assign dataE2[i].pc=dataE[i].pc;
    assign dataE2[i].rdst=dataE[i].rdst;
    assign dataE2[i].ctl=dataE[i].ctl;
    assign dataE2[i].alu_out=dataE[i].alu_out;
    assign dataE2[i].valid=dataE[i].valid;
    assign dataE2[i].cp0_ctl=dataE[i].cp0_ctl;
    assign dataE2[i].is_slot=dataE[i].is_slot;
    assign dataE2[i].cp0ra=dataE[i].cp0ra;
    assign dataE2[i].srcb=dataE[i].srcb;
    assign dataE2[i].hilo=dataE[i].hilo;
end
    
writedata writedata1(.addr(dataE[1].alu_out[1:0]),._wd(dataE[1].srcb),.msize(dataE[1].ctl.msize),.wd(wd[1]),.strobe(strobe[1]),.store_misalign(store_misalign[1]));
writedata writedata2(.addr(dataE[0].alu_out[1:0]),._wd(dataE[0].srcb),.msize(dataE[0].ctl.msize),.wd(wd[0]),.strobe(strobe[0]),.store_misalign(store_misalign[0]));     

assign load_misalign[1]=dataE[1].ctl.memtoreg&&((dataE[1].ctl.msize==MSIZE2&&dataE[0].alu_out[0]!=1'b0)||(dataE[1].ctl.msize==MSIZE4&&dataE[0].alu_out[1:0]!=2'b00));
assign load_misalign[0]=dataE[0].ctl.memtoreg&&(dataE[0].ctl.msize==MSIZE2&&dataE[0].alu_out[0]!=1'b0)||(dataE[0].ctl.msize==MSIZE4&&dataE[0].alu_out[1:0]!=2'b00);

// assign mem_misalign1=(dataE[1].ctl.memtoreg||dataE[1].ctl.memwrite)&&((dataE[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataE[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));

always_comb begin
        dataE2[1].ctl=dataE[1].ctl;
        dataE2[0].ctl=dataE[0].ctl;
        if (dataE[1].cp0_ctl.valid) begin
            dataE2[0].ctl.regwrite='0;
            dataE2[0].ctl.memtoreg='0;
            dataE2[0].ctl.lowrite='0;
            dataE2[0].ctl.hiwrite='0;
            dataE2[0].ctl.cp0write='0;
        end
    end

always_comb begin//都是双端口
        dataE2[1].cp0_ctl=dataE[1].cp0_ctl;
        dataE2[0].cp0_ctl=dataE[0].cp0_ctl;
        if (dataE[1].ctl.memwrite && store_misalign[1]) begin
            dataE2[1].cp0_ctl.ctype=EXCEPTION;
            dataE2[1].cp0_ctl.etype.adesD= '1;
            dataE2[0].cp0_ctl.valid='0;
            dataE2[1].cp0_ctl.valid='1;
        end else if (dataE[0].ctl.memwrite && store_misalign[0]) begin
            dataE2[0].cp0_ctl.ctype=EXCEPTION;
            dataE2[0].cp0_ctl.valid='1;
            dataE2[0].cp0_ctl.etype.adesD='1;
        end
        if (dataE[1].ctl.memtoreg && load_misalign[1]) begin
            dataE2[1].cp0_ctl.ctype=EXCEPTION;
            dataE2[1].cp0_ctl.valid='1;
            dataE2[1].cp0_ctl.etype.adelD= '1;
            dataE2[0].cp0_ctl.valid='0;
        end else if (dataE[0].ctl.memtoreg && load_misalign[0]) begin
            dataE2[0].cp0_ctl.ctype=EXCEPTION;
            dataE2[0].cp0_ctl.valid='1;
            dataE2[0].cp0_ctl.etype.adelD='1;
        end
    end

endmodule

`endif 