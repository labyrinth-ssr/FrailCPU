`ifndef EXECUTE_SV
`define EXECUTE_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`include "alu.sv"
`include "pcbranch.sv"

`endif 

    module execute(
        input clk,resetn,
        input issue_data_t dataI[1:0],
        output execute_data_t dataE[1:0],
        output mem_misalign1
    );

    word_t a[1:0],b[1:0],c[1:0],extend_b[1:0];
    word_t target_offset;
    u1 branch_condition;
    word_t aluout;
    assign extend_b[1] = dataI[1].ctl.zeroext ? {16'b0, dataI[1].imm} : {{16{dataI[1].imm[15]}}, dataI[1].imm};
    assign extend_b[0] = dataI[0].ctl.zeroext ? {16'b0, dataI[0].imm } : {{16{dataI[0].imm [15]}}, dataI[0].imm };
    assign a[1]=dataI[1].rd1;
    assign a[0]=dataI[0].rd1;

    always_comb begin
        for (int i=0; i<2; ++i) begin
            unique case (dataI[i].ctl.alusrc)
                REGB:b[i]=dataI[i].rd2;
                IMM:b[i]=extend_b[i];
            default: b[i]='0;
        endcase
        end
    end
    alu alu_inst1(
        .a(a[1]),
        .b(b[1]),
        .c(aluout),
        .alufunc(dataI[1].ctl.alufunc),
        .exception_of
    );
    assign dataE[1].alu_out=dataI[1].ctl.is_link? dataI[1].pc+12:aluout;

    assign mem_misalign1=(dataI[1].ctl.memtoreg||dataI[1].ctl.memwrite)&&((dataI[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataI[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));

    always_comb begin
        dataE.cp0_ctl=dataI.cp0_ctl;
        if (dataI[1].ctl.memwrite && store_misalign) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            dataE[1].cp0_ctl.etype.adesD='1;
            dataE[0].cp0_ctl.valid='0;
            dataE[1].cp0_ctl.valid='1;
        end else if (dataI[1].ctl.memtoreg && load_misalign) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            dataE[1].cp0_ctl.valid='1;
            dataE[1].cp0_ctl.etype.adelD='1;
            dataE[0].cp0_ctl.valid='0;
        end else if (dataI[0].ctl.memwrite && store_misalign) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adesD='1;
        end else if (dataI[0].ctl.memtoreg && load_misalign) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adelD='1;
        end
    end

    alu alu_inst2(
        .a(a[0]),
        .b(b[0]),
        .c(dataE[0].alu_out),
        .alufunc(dataI[0].ctl.alufunc)
        .exception_of
    );
    assign branch_condition;
    always_comb begin
        dataE[1].target='0;
        if (dataI[1].ctl.branch) begin
            dataE[1].target=dataI[1].pc+4+target_offset;
        end else if (dataI[1].ctl.jr) begin
            dataE[1].target={(dataI[1].pc+4)[31:28],dataI[1].raw_instr[25:0],2'b00};
        end else if (dataI[1].ctl.jump) begin
            dataE[1].target=dataI[1].rd1;
        end
    end

    assign target_offset={{15{dataI[1].raw_instr[15]}},dataI[1].raw_instr[14:0],2'b00};

    pcbranch pcbranch_inst(
        .branch(dataI[1].ctl.branch_type),
        .branch_condition,
        .srca,.srcb,
        .valid(dataI[1].branch)
    );

    assign dataE[1].branch_taken=dataI[1].jump||(dataI[1].branch&&branch_condition);
    assign dataE[1].srcb=dataI[1].rd2;
    assign dataE[0].srcb=dataI[0].rd2;
    assign dataE[0].is_slot=dataI[0].is_slot;
    assign dataE[1].cp0ra=dataI[0].cp0ra;

    always_comb begin
        dataE.ctl=dataI.ctl;
        if (mem_misalign1) begin
            dataE[0].ctl.regwrite='0;
        end
    end

    u1 mult_done,div_done,nega,negb;
    word_t multia,multib;
    u64 multc,divc,multi_res;
    assign multia=dataI[1].rd1;
    assign multib=dataI[1].rd2;
    // assign diva=dataI[1].rd1;
    // assign divb=dataI[1].rd2;
    assign nega=(dataI[1].ctl.op==MULT||dataI[1].ctl.op==DIV)&& dataI[1].rd1[31];
    assign negb=(dataI[1].ctl.op==MULT||dataI[1].ctl.op==DIV)&& dataI[1].rd2[31];
    
    // always_comb begin
    //     {multia,multib,diva,divb}='0;
    //     if
    // end

    multiplier_multicycle_dsp multiplier_multicycle_dsp(
        .clk,.resetn,
        .valid(dataI[1].ctl.op==MULT||dataI[1].ctl.op==MULTU),
        .a(nega? -multia:multia),.b(negb? -multib:multib),
        .done,
        .c (multc)
    );

    assign multi_res= nega^negb? -multc:multc;

    u1 hi_write,lo_write;
    word_t hi_data,lo_data;
    assign dataE[1].hilo={hi_data,lo_data};

    always_comb begin
        // {hi_write,lo_write,hi_data,lo_data}='0;
        if (dataI[1].ctl.op==MULT||dataI[1].ctl.op==MULTU) begin
            {hi_write,lo_write}='1;
            hi_data=multi_res[63:32];
            lo_data=multi_res[31:0];
        end else if (dataI[1].ctl.op==DIV||dataI[1].ctl.op==DIVU) begin
            {hi_write,lo_write}='1;
            unique case ({nega,negb})
            2'b00:begin
                hi_data= divc[63:32];
                lo_data=divc[31:0];
            end
            2'b10:begin
                hi_data= multib-divc[63:32];
                lo_data=-(divc[31:0]+1);
            end
            2'b01:begin
                hi_data= divc[63:32];
                lo_data=-divc[31:0];
            end
            2'b11:begin
                hi_data= -multib-divc[63:32];
                lo_data=divc[31:0]+1;
            end
        endcase
        end
    end

    divider_multicycle_from_single divider_multicycle_from_single(
        .clk,.resetn,
        .valid(dataI[1].ctl.op==DIV||dataI[1].ctl.op==DIVU),
        .a(nega? -multia:multia),.b(negb? -multib:multib),
        .done,
        .c(divc)
    );

    endmodule

`endif