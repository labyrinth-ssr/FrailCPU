`ifndef MYCORE_SV
`define MYCORE_SV


`include "common.svh"
`include "pipes.svh"
`include "mmu_pkg.svh"
`include "cp0_pkg.svh"

`ifdef VERILATOR
`include "regs/pipereg.sv"
`include "regs/pipereg2.sv"
`include "regs/hilo.sv"
`include "regs/regfile.sv"
`include "fetch/pcselect.sv"
`include "decode/decode.sv"
`include "issue/issue.sv"
`include "execute/execute.sv"
`include "memory/memory.sv"
`include "memory/memory2.sv"
`include "bypass.sv"
`include "hazard.sv"
`include "pvtrans.sv"
`include "bpu.sv"
`endif 


module MyCore (
    input logic clk, resetn,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t [1:0]  dreq,
    input  dbus_resp_t [1:0] dresp,
    input logic[5:0] ext_int
);
    /**
     * TODO (Lab1) your code here :)
     */
    
    u1 stallF,stallD,flushD,flushE,flushM,stallM,stallE,flushW,stallM2,flushF2,flushI,flush_que,stallF2,flushM2,stallI,stallI_de;
    u1 is_eret;
    u1 i_wait,d_wait,e_wait;
    u1 is_INTEXC,is_EXC;
    word_t epc;
    u1 excpM,overflowI;
    u1 reset;
    writeback_data_t [1:0]dataW;
    u1 pc_except;
    word_t pc_selected,pc_succ,dataP_pc;
    assign pc_except=dataP_pc[1:0]!=2'b00;
    assign i_wait=ireq.valid && ~iresp.addr_ok;
    assign d_wait= (dreq[1].valid&& ~dresp[1].addr_ok)||(dreq[0].valid&& ~dresp[0].addr_ok);
    u1 pred_taken;
    word_t pre_pc;

    u1 is_jr_ra_decode;
    assign is_jr_ra_decode=(dataD_nxt[1].ctl.op==JR&&dataD_nxt[1].ra1==31)||(dataD_nxt[0].ctl.op==JR&&dataD_nxt[0].ra1==31);

    hazard hazard (
		.stallF,.stallD,.flushD,.flushE,.flushM,.flushI,.flush_que,.i_wait,.d_wait,.stallM,.stallM2,.stallE,.branchM(dataE[1].branch_taken),.e_wait,.clk,.flushW,.excpW(is_eret||is_INTEXC),.stallF2,.flushF2,.stallI,.flushM2,.overflowI,.stallI_de,.excpM,.reset,.branchD(is_jr_ra_decode)
	);

    assign ireq.addr=dataP_pc;
	assign ireq.valid=~(pc_except || is_eret||is_EXC || excpM ||dataE[1].branch_taken||is_jr_ra_decode);
    assign reset=~resetn;

    fetch_data_t [1:0] dataF2_nxt ,dataF2 ;
    decode_data_t [1:0] dataD_nxt ,dataD ;
    issue_data_t [1:0] dataI_nxt,dataI;
    execute_data_t [1:0] dataE_nxt,dataE;
    execute_data_t [1:0] dataM1_nxt,dataM1;
    memory_data_t [1:0] dataM2_nxt,dataM2;

    always_comb begin
        pc_succ=dataP_pc+8;
        if (dataP_pc[2]==1) begin
            pc_succ=dataP_pc+4;
        end
    end

    word_t jpc_save,pc_nxt,dpc_save;
    u1 jpc_saved,dpc_saved;
    always_ff @(posedge clk) begin
        if (reset) begin
            jpc_save<='0;
			jpc_saved<='0;
            dpc_save<='0;
			dpc_saved<='0;
        end else if (stallF && dataE[1].branch_taken) begin
            jpc_save<=pc_selected;
            jpc_saved<='1;
        end else if (stallF && is_jr_ra_decode) begin
            dpc_save<=pc_selected;
            dpc_saved<='1;
        end else if (~stallF) begin
            jpc_save<='0;
			jpc_saved<='0;
		end
	end

    always_comb begin
        if (jpc_saved&&~is_INTEXC) begin
            pc_nxt=jpc_save;
        end else if (dpc_saved&&~dataE[1].branch_taken&&~is_INTEXC) begin
            pc_nxt=dpc_save;
        end else begin
            pc_nxt=pc_selected;
        end
    end

    pcselect pcselect_inst (
        .pc_selected,
        .pc_succ,
        .pc_branch(dataE[1].target),
        .branch_taken(dataE[1].branch_taken),
        .epc,
        .entrance(32'hBFC0_0380),
		.is_eret,
		.is_INTEXC,
        .pred_taken,
        .pre_pc,
        .decode_taken(is_jr_ra_decode)
    );
    //pipereg between pcselect and fetch1

    u1 zero_prej;
    u1 hit_bit;
    assign zero_prej=pred_taken&&~hit_bit;

    fetch1_data_t dataF1_nxt,dataF1;
    assign dataF1_nxt.valid='1;
    assign dataF1_nxt.pc=dataP_pc;
    assign dataF1_nxt.cp0_ctl.ctype= pc_except ? EXCEPTION : NO_EXC;
    assign dataF1_nxt.pre_b= pred_taken&&~zero_prej;
    always_comb begin
        dataF1_nxt.cp0_ctl.etype='0;
        dataF1_nxt.cp0_ctl.vaddr='0;
        dataF1_nxt.cp0_ctl.etype.badVaddrF=pc_except;
    end
    assign dataF1_nxt.cp0_ctl.valid='0;
    // u1 dataF1_pc;
    always_ff @( posedge clk ) begin
		if (reset) begin
			dataP_pc<=32'hbfc0_0000;//
		end else if(~stallF) begin
			dataP_pc<=pc_nxt;
		end
	end
    // word_t pc_f1;

    bpu bpu (
        .clk,.resetn,
        .f1_pc(dataP_pc),
        // .hit(pred_hit),
        .f1_taken(pred_taken),
        .pre_pc,
        // .need_pre()
        .is_jr_ra_decode,
        // .decode_ret_pc,
        // .decode_taken,//预测跳转
        .exe_pc(dataE[1].pc),
        .is_taken(dataE[1].branch_taken),
        .dest_pc(dataE[1].target),
        .ret_pc(dataE[1].pc+8),
        .is_jal(dataE[1].ctl.op==JAL),
        .is_jalr(dataE[1].ctl.op==JALR),
        .is_branch(dataE[1].ctl.branch),
        .is_j(dataE[1].ctl.op==J),
        .is_jr_ra_exe(dataE[1].is_jr_ra),
        .pos(hit_bit)
    );


    u1 branch_valid_i;
    assign branch_valid_i=dataD_nxt[1].ctl.branch;

    // always_comb begin
    //     decode_pre_pc='0;
    //     if (dataD_nxt[branch_valid_i].ctl.branch) begin
    //         if (dataD_nxt[1].ctl.branch) begin
    //             decode_pre_pc=slot_pc+target_offset;
    //         end else if (dataD_nxt[1].ctl.jr) begin
    //             decode_pre_pc=dataD_nxt[1].rd1;
    //         end else if (dataD_nxt[1].ctl.jump) begin
    //             decode_pre_pc={slot_pc[31:28],raw_instr[25:0],2'b00};
    //         end
    //     end
    // end

    // pc_branch pc_branch_decode(
    //     .branch(dataD_nxt[1].ctl.branch_type),
    //     .branch_condition,

    // );
    // assign flushF2=flushF2_hazard||zero_prej;
    pipereg #(.T(fetch1_data_t))F1F2reg(
        .clk,
        .reset,
        .in(dataF1_nxt),
        .out(dataF1),
        .en(~stallF2),
        .flush(flushF2)
    );
    u1 rawinstr_saved;
    u64 raw_instrf2_save;
    u1 delay_flushF2;
    u1 delay_zeroprej;

    always_ff @(posedge clk) begin
        delay_zeroprej<=zero_prej;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            {raw_instrf2_save,rawinstr_saved,delay_flushF2}<='0;
        end else begin
            delay_flushF2 <=flushF2;
            if (stallF2&&~rawinstr_saved) begin
                raw_instrf2_save<=iresp.data;
                rawinstr_saved<='1;
            end else if (~stallF2) begin
                {raw_instrf2_save,rawinstr_saved}<='0;
            end
        end
    end
    //前半部分静止，应当不发起ireq
    always_comb begin
        dataF2_nxt[1].raw_instr= dataF1.pc[2]==1? iresp.data[63:32]:iresp.data[31:0];
        if (dataF1.cp0_ctl.ctype==EXCEPTION) begin
            dataF2_nxt[1].raw_instr='0;
        end else
        if (rawinstr_saved) begin
            dataF2_nxt[1].raw_instr=dataF1.pc[2]==1? raw_instrf2_save[63:32]:raw_instrf2_save[31:0];
        end else if (delay_flushF2) begin
            dataF2_nxt[1].raw_instr='0;
        end 
    end
    always_comb begin
        dataF2_nxt[0].raw_instr=  iresp.data[63:32];
        if (rawinstr_saved) begin
            dataF2_nxt[0].raw_instr=raw_instrf2_save[63:32];
        end else if (delay_flushF2) begin
            dataF2_nxt[0].raw_instr='0;
        end
    end
    assign dataF2_nxt[1].pc=dataF1.pc;
    assign dataF2_nxt[1].pre_b=dataF1.pre_b;
    assign dataF2_nxt[0].pre_b='0;
    // assign dataF2_nxt[1].raw_instr=rawinstr_saved? raw_instrf2_save[31:0]:iresp.data[31:0];
    assign dataF2_nxt[1].valid= dataF1.valid;
    assign dataF2_nxt[1].cp0_ctl=dataF1.cp0_ctl;
    assign dataF2_nxt[0].cp0_ctl='0;

    assign dataF2_nxt[0].pc= (dataF1.pc[2]==1||delay_zeroprej)? '0: dataF1.pc+4;
    // assign dataF2_nxt[0].raw_instr=rawinstr_saved? raw_instrf2_save[63:32]:iresp.data[63:32];
    assign dataF2_nxt[0].valid=/*~pc_except&&*/(~(dataF1.pc[2]==1)||delay_zeroprej) &&dataF1.valid;


    pipereg2 #(.T(fetch_data_t))F2Dreg(
        .clk,
        .reset,
        .in(dataF2_nxt),
        .out(dataF2),
        .en(~stallD),
        .flush(flushD)
    );

    decode decode_inst(
        .dataF2(dataF2),
        .dataD(dataD_nxt)
        // .rd1,.rd2,
        // .ra1,.ra2
    );

    pipereg2 #(.T(decode_data_t))DIreg(
        .clk,
        .reset,
        .in(dataD_nxt),
        .out(dataD),
        .en(~stallI),
        .flush(flushI)
    );
    word_t [1:0]rd1,rd2;
    // creg_addr_t ra1[1:0],ra2[1:0];

    regfile regfile_inst(
        .clk,.reset,
        .ra1({issue_bypass_out[1].ra1,issue_bypass_out[0].ra1}),.ra2({issue_bypass_out[1].ra2,issue_bypass_out[0].ra2}),
        .wa({dataW[1].wa,dataW[0].wa}),
        .wvalid({dataW[1].valid,dataW[0].valid}),
        .wd({dataW[1].wd,dataW[0].wd}),
        .rd1({rd1[1],rd1[0]}),
        .rd2({rd2[1],rd2[0]})
    );

    // decode_data_t readed_dataD[1:0];
    // always_comb begin
    //     readed_dataD=dataD;
    //     for (int i=0; i<2; ++i) begin
    //     readed_dataD[i].rd1=rd1[i];
    //     readed_dataD[i].rd2=rd2[i];
    //     end
    // end

    bypass_input_t [1:0]dataE_in,dataM1_in,dataM2_in;
    bypass_output_t [1:0]bypass_outra1 ,bypass_outra2 ;

    issue issue_inst(
        .clk,.reset,
        .dataD,
        .rd1,.rd2,
        .dataI(dataI_nxt),
        .issue_bypass_out,
        .bypass_inra1(bypass_outra1),
        .bypass_inra2(bypass_outra2),
        .flush_que,
        .stallI,
        .overflow(overflowI),
        .stallI_de
    );

    bypass_issue_t [1:0] dataI_in,issue_bypass_out;
    assign dataI_in=issue_bypass_out;
    bypass_execute_t [1:0] dataEnxt_in;

    bypass bypass_inst(
        .dataE_in,
        .dataM1_in,
        .dataM2_in,
        .dataI_in,
        .dataEnxt_in,
        // .rdstE,
        // .ra1I,.ra2I,
        // .cp0ra,.lo,.hi
        .outra1(bypass_outra1),
        .outra2(bypass_outra2)
    );

    for (genvar i=0; i<2 ;++i) begin
        assign dataE_in[i].data=dataE[i].alu_out;
        assign dataE_in[i].rdst=dataE[i].rdst;
        assign dataE_in[i].memtoreg=dataE[i].ctl.memtoreg;
        assign dataE_in[i].lotoreg=dataE[i].ctl.lotoreg;
        assign dataE_in[i].hitoreg=dataE[i].ctl.hitoreg;
        assign dataE_in[i].cp0toreg=dataE[i].ctl.cp0toreg;
        assign dataE_in[i].regwrite=dataE[i].ctl.regwrite;

        assign dataM1_in[i].data=dataM1[i].alu_out;
        assign dataM1_in[i].rdst=dataM1[i].rdst;
        assign dataM1_in[i].memtoreg=dataM1[i].ctl.memtoreg;
        assign dataM1_in[i].lotoreg=dataM1[i].ctl.lotoreg;
        assign dataM1_in[i].hitoreg=dataM1[i].ctl.hitoreg;
        assign dataM1_in[i].cp0toreg=dataM1[i].ctl.cp0toreg;
        assign dataM1_in[i].regwrite=dataM1[i].ctl.regwrite;

        assign dataM2_in[i].data=dataW[i].wd;
        assign dataM2_in[i].rdst=dataM2[i].rdst;
        assign dataM2_in[i].memtoreg=dataM2[i].ctl.memtoreg;
        assign dataM2_in[i].lotoreg=dataM2[i].ctl.lotoreg;
        assign dataM2_in[i].hitoreg=dataM2[i].ctl.hitoreg;
        assign dataM2_in[i].cp0toreg=dataM2[i].ctl.cp0toreg;
        assign dataM2_in[i].regwrite=dataM2[i].ctl.regwrite;

        assign dataEnxt_in[i].rdst=dataI[i].rdst;
        // assign dataEnxt_in[i].lowrite=dataI[i].ctl.lowrite;
        // assign dataEnxt_in[i].hiwrite=dataI[i].ctl.hiwrite;
        // assign dataEnxt_in[i].cp0write=dataI[i].ctl.cp0write;
        // assign dataEnxt_in[i].cp0ra=dataI[i].cp0ra;
        assign dataEnxt_in[i].regwrite=dataI[i].ctl.regwrite;
    end

    pipereg2 #(.T(issue_data_t))IXreg(
        .clk,
        .reset,
        .in(dataI_nxt),
        .out(dataI),
        .en(~stallE),
        .flush(flushE)
    );

    execute execute_inst(
        .clk,.resetn,
        .dataI,
        .dataE(dataE_nxt),
        .e_wait
    );

    pipereg2 #(.T(execute_data_t))XM1reg(
        .clk,
        .reset,
        .in(dataE_nxt),
        .out(dataE),
        .en(~stallM),
        .flush(flushM)
    );

u1 req1_finish,req2_finish;
    always_ff @(posedge clk) begin
        if (resetn) begin
            if (((dreq[0].valid&&~dresp[0].addr_ok) && dresp[1].addr_ok)) begin
                req1_finish <= '1;
            end
            else if (dresp[0].addr_ok) begin
                req1_finish <= '0;
            end
        end else begin
            req1_finish <= '0;
        end   
    end

    //如果没有。
    always_ff @(posedge clk) begin
        if (resetn) begin
            if ((dreq[1].valid&&~dresp[1].addr_ok) && dresp[0].addr_ok) begin
                req2_finish <= '1;
            end
            else if (dresp[1].addr_ok) begin
                req2_finish <= '0;
            end
        end 
        else begin
            req2_finish <= '0;
        end   
    end

    memory memory(
		.dataE(dataE),
		.dataE2(dataM1_nxt),
		.dreq,
        .req_finish({req1_finish,req2_finish}),
        .excpM
		// .exception(is_eret||is_INTEXC)
	);



	pipereg2 #(.T(execute_data_t)) M1M2reg(
		.clk,.reset,
		.in(dataM1_nxt),
		.out(dataM1),
		.en(~stallM2),
		.flush(flushM2)
	);
	
	memory2 memory2(
        .clk,
		.dataE(dataM1),
		.dataM(dataM2_nxt),
		.dresp,
        .dreq,
        .d_wait,
        .resetn
	);

	pipereg2 #(.T(memory_data_t)) M2Wreg(
		.clk,.reset,
		.in(dataM2_nxt),
		.out(dataM2),
		.en(1'b1),
		.flush(flushW)
	);

    // cp0_regs_t regs_out ;

    writeback writeback(
        // .clk,.reset,
        .dataM(dataM2),
        .dataW,
        .lo_rd,.hi_rd,.cp0_rd
        // .valid_i,.valid_j,.valid_k
    );

    // u1 hi_write,lo_write;

    u1 valid_j,valid_k;
    word_t hi_data,lo_data;
    //同时对hilo进行读是允许的
    always_comb begin
        {hi_data,lo_data}='0;
        {valid_j,valid_k}='0;
        for (int i=1; i>=0; --i) begin
            if (dataM2[i].ctl.hiwrite) begin
                hi_data=dataM2[i].ctl.op==MTHI? dataM2[i].srca:dataM2[i].hilo[63:32];
                valid_j=i[0];
            end 
            if (dataM2[i].ctl.lowrite) begin
                lo_data=dataM2[i].ctl.op==MTLO? dataM2[i].srca:dataM2[i].hilo[31:0];
                valid_k=i[0];
            end
        end
    end
    word_t hi_rd,lo_rd;
    hilo hilo(
    .clk,.reset,
    .hi(hi_rd), .lo(lo_rd),
    .hi_write(dataM2[1].ctl.hiwrite||dataM2[0].ctl.hiwrite), .lo_write(dataM2[1].ctl.lowrite||dataM2[0].ctl.lowrite),
    .hi_data , .lo_data
    );
    
    u1 valid_i,valid_m,valid_n;
    assign valid_i= dataM2[1].ctl.cp0toreg;
    assign valid_m= dataM2[1].ctl.cp0write;
    assign valid_n=dataM2[1].cp0_ctl.ctype==EXCEPTION||dataM2[1].cp0_ctl.ctype==ERET;
    assign is_eret=dataM2[1].cp0_ctl.ctype==ERET || dataM2[0].cp0_ctl.ctype==ERET;
    word_t cp0_rd;

//   assign dataM2_save1.pc=dataM2[1].pc;
//   assign dataM2_save1.valid=dataM2[1].valid;
//   assign dataM2_save1.is_slot=dataM2[1].is_slot;
//   assign dataM2_save1.jump=dataM2[1].ctl.branch||dataM2[1].ctl.jump;
//   assign dataM2_save2.pc=dataM2[0].pc;
//   assign dataM2_save2.valid=dataM2[0].valid;
//   assign dataM2_save2.is_slot=dataM2[0].is_slot;
//   assign dataM2_save2.jump=dataM2[0].ctl.branch||dataM2[0].ctl.jump;
   u1 inter_valid;

	assign inter_valid=~i_wait&&dataM2[1].valid;
    cp0 cp0(
        .clk,.reset,
        .ra(dataM2[valid_i].cp0ra),//直接读写的指令一次发射一条
        .wa(dataM2[valid_m].cp0ra),
        .wd(dataM2[valid_m].srcb),
        .rd(cp0_rd),
        .epc,
        .valid(dataM2[valid_m].ctl.cp0write),
        .is_eret,
        .vaddr(dataM2[valid_n].cp0_ctl.vaddr),
        .ctype(dataM2[valid_n].cp0_ctl.ctype),
        .pc(dataM2[valid_n].pc),
        .etype(dataM2[valid_n].cp0_ctl.etype),
        .ext_int,
        .is_slot(dataM2[valid_n].is_slot),
        .is_INTEXC,
        .inter_valid,
        .is_EXC,
        .int_pc(dataM2[1].pc)
        // .pc_valid(dataM2[valid_n].valid)
        // .dataM2_save({dataM2_save1,dataM2_save2})
    );

endmodule

`endif