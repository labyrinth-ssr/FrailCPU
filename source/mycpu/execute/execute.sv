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
        input u1 d_wait,
        output e_wait,
        input bypass_output_t [1:0] bypass_inra1,bypass_inra2
        // output u1 cache_instE,
        // output word_t iaddrE
    );

    word_t a[1:0],b[1:0],extend_b[1:0];
    word_t [1:0] rd1,rd2;
    word_t [1:0] bypass_save_rd1,bypass_save_rd2;
    u1 [1:0]bypass_rd1_saved,bypass_rd2_saved;

    u1 stallE;
    assign stallE=e_wait||d_wait;


    for (genvar i = 0;i<2 ; ++i) begin
        always_comb begin
            rd1[i]=dataI[i].rd1;
            rd2[i]=dataI[i].rd2;
            if (bypass_inra1[i].bypass) begin
                rd1[i]=bypass_inra1[i].data;
            end else if (bypass_rd1_saved[i]) begin
                rd1[i]=bypass_save_rd1[i];
            end

            if (bypass_inra2[i].bypass) begin
                rd2[i]=bypass_inra2[i].data;
            end else if (bypass_rd2_saved[i]) begin
                rd2[i]=bypass_save_rd2[i];
            end
        end

        always_ff @(posedge clk) begin
            if (stallE&&bypass_inra1[i].bypass) begin
                bypass_save_rd1[i] <= bypass_inra1[i].data;
                bypass_rd1_saved[i] <='1;
            end else if (~stallE) begin
                bypass_rd1_saved[i]<='0;
                bypass_save_rd1[i]<= '0;
            end
            if (stallE&&bypass_inra2[i].bypass) begin
                bypass_save_rd2[i]<= bypass_inra2[i].data;
                bypass_rd2_saved[i]<='1;
            end else if (~stallE) begin
                bypass_rd2_saved[i]<='0;
                bypass_save_rd2[i]<= '0;
            end
        end
        // assign rd1[i]=bypass_inra1[i].bypass? bypass_inra1[i].data:dataI[i].rd1;
        // assign rd2[i]=bypass_inra2[i].bypass? bypass_inra2[i].data:dataI[i].rd2;
    end
    word_t target_offset;
    u1 branch_condition;
    word_t aluout;
    assign extend_b[1] = dataI[1].ctl.zeroext ? {16'b0, dataI[1].imm} : {{16{dataI[1].imm[15]}}, dataI[1].imm};
    assign extend_b[0] = dataI[0].ctl.zeroext ? {16'b0, dataI[0].imm } : {{16{dataI[0].imm [15]}}, dataI[0].imm };
    assign a[1]= dataI[1].ctl.shamt_valid? {27'b0,dataI[1].raw_instr [10:6]} : rd1[1];
    assign a[0]=dataI[0].ctl.shamt_valid? {27'b0, dataI[0].raw_instr [10:6]} :rd1[0];

    // u1 1;
    // assign 1=dataI[1].ctl.cache;
    // assign dataE[1].cache_inst_i=dataI[1].ctl.cache_i;
    // assign dataE[0].cache_inst_i=dataI[0].ctl.cache_i;

    // assign dataE[1].cache_addr=  aluout;
    // assign dataE[0].cache_addr=  '0;
    // assign cache_instE=dataI[1].ctl.cache||dataI[0].ctl.cache;
    // assign iaddrE= 1 ? aluout : aluout2;

    u1 exception_of[1:0];
    word_t aluout2;

    always_comb begin
        for (int i=0; i<2; ++i) begin
            unique case (dataI[i].ctl.alusrc)
                REGB:b[i]=rd2[i];
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
    word_t target;
    always_comb begin
        target='0;
        if (dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b) begin
            target=slot_pc+target_offset;
        end else if (dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b) begin
            target=dataI[1].pc+8;  
        end else if (dataI[1].ctl.jr /*&&~dataI[1].pre_b*/) begin
            target=rd1[1];
        end else if (dataI[1].ctl.jump/*&&~dataI[1].pre_b*/) begin
            target={slot_pc[31:28],raw_instr[25:0],2'b00};
        end else if (dataI[1].ctl.cache_i||dataI[1].ctl.cache_d||dataI[1].ctl.tlb) begin
            target=dataI[1].pc+4;
        end
    end
    assign dataE[1].target=target;
    assign dataE[0].dest_pc='0;

    always_comb begin
        dataE[1].dest_pc='0;
        if (dataI[1].ctl.branch) begin
            dataE[1].dest_pc=slot_pc+target_offset;
        end else if (dataI[1].ctl.jr ) begin
            dataE[1].dest_pc=rd1[1];
        end else if (dataI[1].ctl.jump) begin
            dataE[1].dest_pc={slot_pc[31:28],raw_instr[25:0],2'b00};
        end
    end

    assign dataE[0].target='0;
    assign dataE[0].branch_taken='0;

    // real fail_b;
    // real total_b;
    // logic[28:0] print_cnt;
    // always_ff @(posedge clk)begin
    //     if(print_cnt[15] == 1)begin
    //         $display("b-type success rate:%.2f %%", (total_b-fail_b)/total_b*100);
    //         print_cnt<='0;
    //         // $display("b-type pred-fail_b rate:%.2f %%", (total_b-fail_b)/total_b*100);
    //     end else begin
    //         print_cnt <= print_cnt + 1;
    //         if ((dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b)
    //             ||(dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b))begin
    //             fail_b <= fail_b + 1;
    //         end
    //         if(dataI[1].ctl.branch) begin
    //             total_b <= total_b + 1;
    //         end
    //     end
    // end

    // real fail_j;
    // real total_j;
    // logic[28:0] print_cnt_j;
    // always_ff @(posedge clk)begin
    //     if(print_cnt_j[15] == 1)begin
    //         $display("j-type success rate:%.2f %%", (total_j-fail_j)/total_j*100);
    //         print_cnt_j<='0;
    //     end else begin
    //         print_cnt_j <= print_cnt_j + 1;
    //         if (dataI[1].ctl.jump&&~dataI[1].pre_b)begin
    //             fail_j <= fail_j + 1;
    //         end
    //         if(dataI[1].ctl.jump) begin
    //             total_j <= total_j + 1;
    //         end
    //     end
    // end


    assign target_offset={{15{raw_instr[15]}},raw_instr[14:0],2'b00};

    pcbranch pcbranch_inst(
        .branch(dataI[1].ctl.branch_type),
        .branch_condition,
        .srca(rd1[1]),.srcb(rd2[1]),
        .valid(dataI[1].ctl.branch)
    );

    assign dataE[1].branch_taken=(dataI[1].ctl.jump&&~(dataI[1].pre_b&&dataI[1].pre_pc==target))
    ||(dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b)
    ||(dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b)||dataI[1].ctl.tlb||dataI[1].ctl.cache_d;

    for (genvar i=0; i<2; ++i) begin
        assign dataE[i].srcb=rd2[i];
        assign dataE[i].srca=rd1[i];
        assign dataE[i].rdst=dataI[i].rdst;
        assign dataE[i].pc=dataI[i].pc;
        assign dataE[i].cache_ctl=dataI[i].cache_ctl;
        assign dataE[i].i_tlb_exc=dataI[i].i_tlb_exc;
    // assign dataE[i].ctl=dataI[i].ctl;
    end

    
    u1 [1:0] trap;
    assign trap[1]=dataI[1].ctl.tne && (rd1[1]==rd2[1]);
    assign trap[0]=dataI[0].ctl.tne && (rd1[0]==rd2[0]);


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

    assign multia= rd1[valid_i];
    assign multib= rd2[valid_i];
    // assign diva=rd1[1];bypass_b_saved? bypass_save_b : 
    // assign divb=dataI[1].rd2;bypass_a_saved? bypass_save_a : 
    assign nega=dataI[valid_i].ctl.signed_mul_div&& multia[31];
    assign negb=dataI[valid_i].ctl.signed_mul_div&& multib[31];
    
    // always_comb begin
    //     {multia,multib,diva,divb}='0;
    //     if
    // end
    u1 mult_valid,div_valid;
    assign mult_valid=dataI[1].ctl.mul||dataI[0].ctl.mul;
    assign div_valid=dataI[1].ctl.div||dataI[0].ctl.div;

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
        if (dataI[1].ctl.mul||dataI[1].ctl.div) begin
            valid_i='1;
        end 
        // else if (dataI[0].ctl.op==MULT||dataI[0].ctl.op==MULTU||dataI[0].ctl.op==DIV||dataI[0].ctl.op==DIVU) begin
        //     valid_i='0;
        // end
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



    // always_ff @(posedge clk) begin
    //     if (e_wait&&bypass_inra1[valid_i].bypass) begin
    //         bypass_save_a <= bypass_inra1[valid_i].data;
    //         bypass_a_saved<='1;
    //     end else if (~e_wait) begin
    //         bypass_a_saved<='0;
    //         bypass_save_a <= '0;
    //     end
    //     if (e_wait&&bypass_inra2[valid_i].bypass) begin
    //         bypass_save_b <= bypass_inra2[valid_i].data;
    //         bypass_b_saved<='1;
    //     end else if (~e_wait) begin
    //         bypass_b_saved<='0;
    //         bypass_save_b <= '0;
    //     end
    // end

    u1 [1:0] load_misalign,store_misalign;

    assign load_misalign[1]=~|dataI[1].ctl.memtype&& dataI[1].ctl.memtoreg&&((dataI[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataI[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));
    assign load_misalign[0]=~|dataI[0].ctl.memtype&& dataI[0].ctl.memtoreg&&((dataI[0].ctl.msize==MSIZE2&&aluout2[0]!=1'b0)||(dataI[0].ctl.msize==MSIZE4&&aluout2[1:0]!=2'b00));
    assign store_misalign[1]=~|dataI[1].ctl.memtype&& dataI[1].ctl.memwrite&&((dataI[1].ctl.msize==MSIZE2&&aluout[0]!=1'b0)||(dataI[1].ctl.msize==MSIZE4&&aluout[1:0]!=2'b00));
    assign store_misalign[0]=~|dataI[0].ctl.memtype&& dataI[0].ctl.memwrite&&((dataI[0].ctl.msize==MSIZE2&&aluout2[0]!=1'b0)||(dataI[0].ctl.msize==MSIZE4&&aluout2[1:0]!=2'b00));

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
            end else if (store_misalign[0]) begin
                dataE[0].ctl.memwrite='0;
            end

            if (dataI[1].cp0_ctl.ctype==EXCEPTION||exception_of[1]) begin
                dataE[0].ctl.memwrite='0;
            end

            
            if(dataI[1].ctl.op == MOVZ && (|rd2[1]))begin // rd2[1] != '0
                dataE[1].ctl.regwrite='0;
            end
            if(dataI[0].ctl.op == MOVZ && (|rd2[0]))begin //rd2[0] != '0
                dataE[0].ctl.regwrite='0;
            end
            if(dataI[1].ctl.op == MOVN && ~(|rd2[1]))begin // rd2[1] == '0
                dataE[1].ctl.regwrite='0;
            end
            if(dataI[0].ctl.op == MOVN && ~(|rd2[0]))begin //rd2[0] == '0
                dataE[0].ctl.regwrite='0;
            end

    end

        
    assign dataE[1].valid=dataI[1].valid;
    assign dataE[0].valid= exception_of[1]? '0 : dataI[0].valid;

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
            // dataE[1].cp0_ctl.valid='1;
            // dataE[1].cp0_ctl.vaddr=aluout;
        end else if (store_misalign[0]) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            // dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adesD='1;
            // dataE[0].cp0_ctl.vaddr=aluout2;
        end
        if ( load_misalign[1]) begin
            dataE[1].cp0_ctl.ctype=EXCEPTION;
            // dataE[1].cp0_ctl.valid='1;
            dataE[1].cp0_ctl.etype.adelD= '1;
            // dataE[1].cp0_ctl.vaddr=aluout;
        end else if ( load_misalign[0]) begin
            dataE[0].cp0_ctl.ctype=EXCEPTION;
            // dataE[0].cp0_ctl.valid='1;
            dataE[0].cp0_ctl.etype.adelD='1;
            // dataE[0].cp0_ctl.vaddr=aluout2;
        end

        priority case(1'b1)
            trap[1]:begin
                dataE[1].cp0_ctl.ctype=EXCEPTION;
                dataE[1].cp0_ctl.etype.trap='1;
            end
            trap[0]:begin
                dataE[0].cp0_ctl.ctype=EXCEPTION;
                dataE[0].cp0_ctl.etype.trap='1;                
            end
            default:;
        endcase
    end


    // real fail_b;
    // real total_b;
    // logic[28:0] print_cnt;
    // always_ff @(posedge clk)begin
    //     if(print_cnt[15] == 1)begin
    //         $display("b-type success rate:%.2f %%", (total_b-fail_b)/total_b*100);
    //         print_cnt<='0;
    //         // $display("b-type pred-fail_b rate:%.2f %%", (total_b-fail_b)/total_b*100);
    //     end else begin
    //         print_cnt <= print_cnt + 1;
    //         if ((dataI[1].ctl.branch&&branch_condition&&~dataI[1].pre_b)
    //             ||(dataI[1].ctl.branch&&~branch_condition&&dataI[1].pre_b))begin
    //             fail_b <= fail_b + 1;
    //         end
    //         if(dataI[1].ctl.branch) begin
    //             total_b <= total_b + 1;
    //         end
    //     end
    // end

    // real fail_j;
    // real total_j;
    // logic[28:0] print_cnt_j;
    // always_ff @(posedge clk)begin
    //     if(print_cnt_j[15] == 1)begin
    //         $display("j-type success rate:%.2f %%", (total_j-fail_j)/total_j*100);
    //         print_cnt_j<='0;
    //     end else begin
    //         print_cnt_j <= print_cnt_j + 1;
    //         if (dataI[1].ctl.jump&&~(dataI[1].pre_b&&dataI[1].pre_pc==target))begin
    //             fail_j <= fail_j + 1;
    //         end
    //         if(dataI[1].ctl.jump) begin
    //             total_j <= total_j + 1;
    //         end
    //     end
    // end

    endmodule

`endif