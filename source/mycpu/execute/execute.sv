`ifndef EXECUTE_SV
`define EXECUTE_SV


`include "common.svh"
`include "pipes.svh"
`ifdef VERILATOR
`include "alu.sv"
`include "pcbranch.sv"
`include "alu/multi.sv"
`include "alu/div.sv"
`endif 

    module execute(
        input clk,resetn,
        input issue_data_t [1:0] dataI,
        output execute_data_t [1:0] dataE,
        output e_wait
    );

    word_t a[1:0],b[1:0],extend_b[1:0];
    word_t target_offset;
    u1 branch_condition;
    word_t aluout;
    assign extend_b[1] = dataI[1].ctl.zeroext ? {16'b0, dataI[1].imm} : {{16{dataI[1].imm[15]}}, dataI[1].imm};
    assign extend_b[0] = dataI[0].ctl.zeroext ? {16'b0, dataI[0].imm } : {{16{dataI[0].imm [15]}}, dataI[0].imm };
    assign a[1]= dataI[1].ctl.shamt_valid? {27'b0,dataI[1].raw_instr [10:6]} : dataI[1].rd1;
    assign a[0]=dataI[0].ctl.shamt_valid? {27'b0, dataI[0].raw_instr [10:6]} :dataI[0].rd1;

    u1 exception_of[1:0];
    word_t aluout2;

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
        .exception_of(exception_of[1])
    );

    alu alu_inst2(
        .a(a[0]),
        .b(b[0]),
        .c(aluout2),
        .alufunc(dataI[0].ctl.alufunc),
        .exception_of(exception_of[0])
    );

    assign dataE[0].alu_out=aluout2;
    assign dataE[1].alu_out=dataI[1].ctl.is_link? dataI[1].pc+8:aluout;
    
    word_t slot_pc;
    assign slot_pc=dataI[1].pc+4;
    word_t raw_instr;
    assign raw_instr=dataI[1].raw_instr;
    always_comb begin
        dataE[1].target='0;
        if (dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b) begin
            dataE[1].target=slot_pc+target_offset;
        end else if (dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b) begin
            dataE[1].target=dataI[1].pc+8;  
        end else if (dataI[1].ctl.jr &&~dataI[1].pre_b) begin
            dataE[1].target=dataI[1].rd1;
        end else if (dataI[1].ctl.jump&&~dataI[1].pre_b) begin
            dataE[1].target={slot_pc[31:28],raw_instr[25:0],2'b00};
        end
    end
    assign dataE[0].dest_pc='0;

    always_comb begin
        dataE[1].dest_pc='0;
        if (dataI[1].ctl.branch) begin
            dataE[1].dest_pc=slot_pc+target_offset;
        end else if (dataI[1].ctl.jr ) begin
            dataE[1].dest_pc=dataI[1].rd1;
        end else if (dataI[1].ctl.jump) begin
            dataE[1].dest_pc={slot_pc[31:28],raw_instr[25:0],2'b00};
        end
    end

    assign dataE[0].target='0;
    assign dataE[0].branch_taken='0;

    assign target_offset={{15{raw_instr[15]}},raw_instr[14:0],2'b00};

    pcbranch pcbranch_inst(
        .branch(dataI[1].ctl.branch_type),
        .branch_condition,
        .srca(dataI[1].rd1),.srcb(dataI[1].rd2),
        .valid(dataI[1].ctl.branch)
    );

    assign dataE[1].branch_taken=(dataI[1].ctl.jump&&~dataI[1].pre_b)
    ||(dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b)
    ||(dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b);

    for (genvar i=0; i<2; ++i) begin
    assign dataE[i].srcb=dataI[i].rd2;
    assign dataE[i].srca=dataI[i].rd1;
    assign dataE[i].rdst=dataI[i].rdst;
    assign dataE[i].pc=dataI[i].pc;
    // assign dataE[i].ctl=dataI[i].ctl;
    end
    assign dataE[1].valid=dataI[1].valid;
    assign dataE[0].valid= exception_of[1]? '0 : dataI[0].valid;

    assign dataE[0].is_slot=dataI[0].is_slot;
    assign dataE[1].is_slot='0;

    assign dataE[0].cp0ra=dataI[0].cp0ra;
    assign dataE[1].cp0ra=dataI[1].cp0ra;

    assign dataE[1].is_jr_ra=dataI[1].is_jr_ra;
    assign dataE[0].is_jr_ra='0;

    u1 mult_done,div_done,nega,negb;
    word_t multia,multib;
    u64 multc,divc,multi_res;    
    u1 valid_i;

    assign multia=dataI[valid_i].rd1;
    assign multib=dataI[valid_i].rd2;
    // assign diva=dataI[1].rd1;
    // assign divb=dataI[1].rd2;
    assign nega=(dataI[valid_i].ctl.op==MULT||dataI[valid_i].ctl.op==DIV)&& dataI[valid_i].rd1[31];
    assign negb=(dataI[valid_i].ctl.op==MULT||dataI[valid_i].ctl.op==DIV)&& dataI[valid_i].rd2[31];
    
    // always_comb begin
    //     {multia,multib,diva,divb}='0;
    //     if
    // end
    u1 mult_valid,div_valid;
    assign mult_valid=dataI[1].ctl.op==MULT||dataI[1].ctl.op==MULTU||dataI[0].ctl.op==MULT||dataI[0].ctl.op==MULTU;
    assign div_valid=dataI[1].ctl.op==DIV||dataI[1].ctl.op==DIVU||dataI[0].ctl.op==DIV||dataI[0].ctl.op==DIVU;

    multi multiplier_multicycle_dsp(
        .clk,.resetn,
        .valid(mult_valid),
        .a(nega? -multia:multia),.b(negb? -multib:multib),
        .done(mult_done),
        .c (multc)
    );
        div divider_multicycle_from_single(
        .clk,.resetn,
        .valid(div_valid),
        .a(nega? -multia:multia),.b(negb? -multib:multib),
        .done(div_done),
        .c(divc)
    );

    assign multi_res= nega^negb? -multc:multc;

    // u1 hi_write,lo_write;
    word_t hi_data,lo_data;

    always_comb begin
        if(valid_i == 1'b1) begin
            dataE[1].hilo={hi_data,lo_data};
            dataE[0].hilo='0;
        end else begin
            dataE[0].hilo={hi_data,lo_data};
            dataE[1].hilo='0;
        end
    end

    always_comb begin
        valid_i='0;
        if (dataI[1].ctl.op==MULT||dataI[1].ctl.op==MULTU||dataI[1].ctl.op==DIV||dataI[1].ctl.op==DIVU) begin
            valid_i='1;
        end else if (dataI[0].ctl.op==MULT||dataI[0].ctl.op==MULTU||dataI[0].ctl.op==DIV||dataI[0].ctl.op==DIVU) begin
            valid_i='0;
        end
    end

    always_comb begin
        {hi_data,lo_data}='0;
        if (mult_valid) begin
            // {hi_write,lo_write}='1;
            hi_data=multi_res[63:32];
            lo_data=multi_res[31:0];
        end else if (div_valid) begin
            // {hi_write,lo_write}='1;
            lo_data= nega^negb? -divc[31:0] : divc[31:0];
            hi_data=nega? -divc[63:32]:divc[63:32];
        end
    end

    assign e_wait=((div_valid)&&~div_done)||((mult_valid)&&~mult_done);

    u1 [1:0] load_misalign,store_misalign;

    assign load_misalign[1]=dataI[1].ctl.memtoreg&&((dataI[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataI[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));
    assign load_misalign[0]=dataI[0].ctl.memtoreg&&((dataI[0].ctl.msize==MSIZE2&&aluout2[0]!=1'b0)||(dataI[0].ctl.msize==MSIZE4&&aluout2[1:0]!=2'b00));
    assign store_misalign[1]=dataI[1].ctl.memwrite&&((dataI[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataI[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));
    assign store_misalign[0]=dataI[0].ctl.memwrite&&((dataI[0].ctl.msize==MSIZE2&&aluout2[0]!=1'b0)||(dataI[0].ctl.msize==MSIZE4&&aluout2[1:0]!=2'b00));

    always_comb begin
        dataE[1].ctl=dataI[1].ctl;
        dataE[0].ctl=dataI[0].ctl;

            if (load_misalign[1]) begin
                dataE[1].ctl.memtoreg='0;
                dataE[0].ctl.memtoreg='0;
                dataE[0].ctl.memwrite='0;
            end else if (store_misalign[1]) begin
                dataE[1].ctl.memwrite='0;
                dataE[0].ctl.memtoreg='0;
                dataE[0].ctl.memwrite='0;
            end

            if (load_misalign[0]) begin
                dataE[0].ctl.memtoreg='0;
            end else if (load_misalign[0]) begin
                dataE[0].ctl.memwrite='0;
            end

    end

    always_comb begin//都是双端口
        dataE[1].cp0_ctl=dataI[1].cp0_ctl;
        dataE[0].cp0_ctl=dataI[0].cp0_ctl;
        if (exception_of[1]) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            dataE[1].cp0_ctl.etype.overflow= '1;
        end
        else if (exception_of[0]) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            dataE[0].cp0_ctl.etype.overflow= '1;
        end

        if (store_misalign[1]) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            dataE[1].cp0_ctl.etype.adesD= '1;
            dataE[1].cp0_ctl.valid='1;
            dataE[1].cp0_ctl.vaddr=aluout;
        end else if (store_misalign[0]) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adesD='1;
            dataE[0].cp0_ctl.vaddr=aluout2;
        end
        if ( load_misalign[1]) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            dataE[1].cp0_ctl.valid='1;
            dataE[1].cp0_ctl.etype.adelD= '1;
            dataE[1].cp0_ctl.vaddr=aluout;
        end else if ( load_misalign[0]) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adelD='1;
            dataE[0].cp0_ctl.vaddr=aluout2;
        end
    end

    endmodule

`endif