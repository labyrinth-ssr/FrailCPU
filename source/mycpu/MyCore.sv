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
`include "memory/memory3.sv"
`include "bypass.sv"
`include "hazard.sv"
`include "pvtrans.sv"
// `include "bpu.sv"
`endif 

module MyCore (
    input logic clk, resetn,
    output ibus_req_t  ireq,
    input  ibus_resp_t iresp,
    output dbus_req_t [1:0]  dreq,
    input  dbus_resp_t dresp,
    input logic[5:0] ext_int
);
    /**
     * TODO (Lab1) your code here :)
     */
    u1 stallF,stallD,flushD,flushE,flushM,stallM,stallE,flushW,stallM2,flushF3,flushI,flush_que,stallF3,flushM2,stallI,stallI_de,flushM3,stallF2,flushF2/*,flushF3_delay*/;
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
    assign i_wait=~iresp.addr_ok;
    u1 delay_flushF3;
    // assign d_wait= (dreq[1].valid&& ~dresp[1].addr_ok)||(dreq[0].valid&& ~dresp[0].addr_ok);
    // u1 pred_taken;
    // word_t pre_pc;
    // u1 jr_ra_fail;


    // u1 is_jr_ra_decode;
    // assign is_jr_ra_decode=(dataD_nxt[1].ctl.op==JR&&dataD_nxt[1].ra1==31)||(dataD_nxt[0].ctl.op==JR&&dataD_nxt[0].ra1==31);
    // u1 jrD;
    // // assign jrD=is_jr_ra_decode&&~jr_ra_fail;
    // assign jrD='0;

    // u1 save_slotD;
    // assign save_slotD=dataD_nxt[0].ctl.op==JR&&dataD_nxt[0].ra1==31;
    logic dreq_valid;
    assign d_wait= ~dresp.addr_ok;
    // always_ff @(posedge clk) begin
    //     if (resetn) begin
    //         dreq_valid <= dreq[0].valid | dreq[1].valid;
    //     end
    //     else begin
    //         dreq_valid <= '0;
    //     end
    // end

    hazard hazard (
		.stallF,.stallD,.flushD,.flushE,.flushM,.flushI,.flush_que,.i_wait,.d_wait,.stallM,.stallM2,.stallE,.branchM(dataE[1].branch_taken),.e_wait,.clk,.flushW,.excpW(is_eret||is_INTEXC),.stallF3,.flushF3,.stallI,.flushM2,.overflowI,.stallI_de,.excpM,.reset,.flushM3,.stallF2,.flushF2/*,.flushF3_delay*/
	);

    // assign ireq.addr=dataP_pc;
	assign ireq.valid=~pc_except /*|| is_eret||is_EXC || excpM*/;
    assign reset=~resetn;

    fetch_data_t [1:0] dataF3_nxt ,dataF3 ;
    decode_data_t [1:0] dataD_nxt ,dataD ;
    issue_data_t [1:0] dataI_nxt,dataI;
    execute_data_t [1:0] dataE_nxt,dataE;
    execute_data_t [1:0] dataM1_nxt,dataM1;
    execute_data_t [1:0] dataM2_nxt,dataM2;
    memory_data_t [1:0] dataM3_nxt,dataM3;

    // always_comb begin
    assign pc_succ=dataP_pc+8;
    //     if (dataP_pc[2]==1) begin
    //         pc_succ=dataP_pc+4;
    //     end
    // end

    word_t jpc_save,ipc_save,pc_nxt;
    u1 jpc_saved,ipc_saved;
    always_ff @(posedge clk) begin
        if (reset) begin
            {jpc_save,ipc_save,jpc_saved,ipc_saved}<='0;
        end else if (stallF2&&(is_EXC||is_eret)) begin
			ipc_save<=dataP_pc;
			ipc_saved<='1;
        end else if (stallF2 && dataE[1].branch_taken) begin
            jpc_save<=dataP_pc;
            jpc_saved<='1;
        end /*else if (stallF2 && jrD) begin
            dpc_save<=pc_selected;
            dpc_saved<='1;
        end */else if (~stallF2) begin
			ipc_save<='0;
			ipc_saved<='0;
            jpc_save<='0;
			jpc_saved<='0;
            // dpc_save<='0;
			// dpc_saved<='0;
		end
	end
    assign pc_nxt=pc_selected;

    always_comb begin
        if (ipc_saved) begin
            ireq.addr=ipc_save;
        end else if (jpc_saved&&~is_EXC&&~is_eret) begin
            ireq.addr=jpc_save;
        end /*else if (dpc_saved&&~dataE[1].branch_taken&&~is_INTEXC) begin
            ireq.addr=dpc_save;
        end */else begin
            ireq.addr=dataP_pc;
        end
    end

    // u1 j_misalign_hazard;
    // u1 jr_pc_saved;
    // word_t jr_pc_save;
    // assign j_misalign_hazard= pred_taken&&hit_bit&&dataP_pc[2];pred_pc_saved,pred_pc_save,
    // u1 zero_prej;
    // u1 hit_bit;
    // assign zero_prej=pred_taken&&~hit_bit;
    // u1 jrD_misalign;
    // assign jrD_misalign=jrD&&save_slotD;

    // always_ff @(posedge clk) begin
    //     if (jrD_misalign) begin
    //         pred_pc_save<=pre_pc;
    //         jr_pc_saved<='1;
    //     end else if (j_misalign_hazard||zero_prej) begin
    //         pred_pc_save<=pre_pc;
    //         pred_pc_saved<='1;
    //     end else if (~stallF) begin
    //         {pred_pc_save,pred_pc_saved}<='0;
    //     end
    // end


    pcselect pcselect_inst (
        .pc_selected,
        .pc_succ,
        .pc_branch(dataE[1].target),
        .branch_taken(dataE[1].branch_taken),
        .epc,
        .entrance(32'hBFC0_0380),
		.is_eret,
		.is_INTEXC
        // .pred_taken(pred_taken&&~zero_prej),
        // .pre_pc(pre_pc),
        // .decode_taken(jrD&&~save_slotD),
        // .refetchD_pc(dataD_nxt[0].pc),
        // .select_refetchD(jrD_misalign),
        // .zero_prej
    );
    //pipereg between pcselect and fetch1
    fetch1_data_t dataF1_nxt,dataF1;
    fetch1_data_t dataF2_nxt,dataF2;
    assign dataF1_nxt.valid='1;
    assign dataF1_nxt.pc=dataP_pc;
    assign dataF1_nxt.cp0_ctl.ctype= pc_except ? EXCEPTION : NO_EXC;
    // assign dataF1_nxt.pre_b= pred_taken&&~zero_prej;
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

    // bpu bpu (
    //     .clk,.resetn,
    //     .f1_pc(dataP_pc),
    //     // .hit(pred_hit),
    //     .f1_taken(pred_taken),
    //     .pre_pc,
    //     // .need_pre()
    //     .is_jr_ra_decode,
    //     .jr_ra_fail,
    //     // .decode_ret_pc,
    //     // .decode_taken,//预测跳转
    //     .exe_pc(dataE[1].pc),
    //     .is_taken(dataE[1].branch_taken),
    //     .dest_pc(dataE[1].dest_pc),
    //     .ret_pc(dataE[1].pc+8),
    //     .is_jal(dataE[1].ctl.op==JAL),
    //     .is_jalr(dataE[1].ctl.op==JALR),
    //     .is_branch(dataE[1].ctl.branch),
    //     .is_j(dataE[1].ctl.op==J),
    //     .is_jr_ra_exe(dataE[1].is_jr_ra),
    //     .pos(hit_bit)
    // );


    // u1 branch_valid_i;
    // assign branch_valid_i=dataD_nxt[1].ctl.branch;

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

    assign dataF2_nxt=dataF1;

    pipereg #(.T(fetch1_data_t))F2F3reg(
        .clk,
        .reset,
        .in(dataF2_nxt),
        .out(dataF2),
        .en(~stallF3),
        .flush(flushF3)
    );
    

    
    u1 rawinstr_saved;
    u64 raw_instrf2_save;
    // u1 delay_flushF3;
    // u1 flushF3_d,flushF3_dd;
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         {flushF3_d,flushF3_dd}<='0;
    //     end else begin
    //         flushF3_d<=flushF3_delay;
    //         flushF3_dd<=flushF3_d;
    //     end
    // end
    // u1 delay_zeroprej;

    // always_ff @(posedge clk) begin
    //     delay_zeroprej<=zero_prej||pred_pc_saved;
    // end

    always_ff @(posedge clk) begin
        if (reset) begin
            {raw_instrf2_save,rawinstr_saved,delay_flushF3}<='0;
        end else begin
            delay_flushF3 <=flushF3;
            if (stallF3&&~rawinstr_saved) begin
                raw_instrf2_save<=iresp.data;
                rawinstr_saved<='1;
            end else if (~stallF3) begin
                {raw_instrf2_save,rawinstr_saved}<='0;
            end
        end
    end
    //前半部分静止，应当不发起ireq
    // u1 delay_save_slotD;
    // always_ff @(posedge clk) begin
    //     delay_save_slotD<=save_slotD;
    // end

    // u1 rawinstr_saved_delay;
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         rawinstr_saved_delay<='0;
    //     end else begin
    //         rawinstr_saved_delay<=rawinstr_saved;
    //     end
    // end

    always_comb begin
        dataF3_nxt[1].raw_instr=  iresp.data[31:0];
        if (dataF2.cp0_ctl.ctype==EXCEPTION) begin
            dataF3_nxt[1].raw_instr='0;
        end else
        if (rawinstr_saved/*||rawinstr_saved_delay*/) begin
            dataF3_nxt[1].raw_instr= raw_instrf2_save[31:0];
        end else if (delay_flushF3/*||flushF3_d||flushF3_dd*/) begin
            dataF3_nxt[1].raw_instr='0;
        end 
    end

    always_comb begin
        dataF3_nxt[0].raw_instr=  iresp.data[63:32];
        if (rawinstr_saved/*||rawinstr_saved_delay*/) begin
            dataF3_nxt[0].raw_instr=raw_instrf2_save[63:32];
        end else if (delay_flushF3/*||flushF3_d||flushF3_dd*/) begin
            dataF3_nxt[0].raw_instr='0;
        end
    end

    assign dataF3_nxt[1].pc=dataF2.pc;
    // assign dataF3_nxt[1].pre_b=dataF1.pre_b;
    // assign dataF3_nxt[0].pre_b='0;
    // assign dataF3_nxt[1].raw_instr=rawinstr_saved? raw_instrf2_save[31:0]:iresp.data[31:0];
    assign dataF3_nxt[1].valid= dataF2.valid;
    assign dataF3_nxt[1].cp0_ctl=dataF2.cp0_ctl;
    assign dataF3_nxt[0].cp0_ctl='0;

    assign dataF3_nxt[0].pc= dataF2.pc+4;
    // assign dataF3_nxt[0].raw_instr=rawinstr_saved? raw_instrf2_save[63:32]:iresp.data[63:32];
    assign dataF3_nxt[0].valid=/*~pc_except&&*/dataF2.valid;

    pipereg2 #(.T(fetch_data_t))F3Dreg(
        .clk,
        .reset,
        .in(dataF3_nxt),
        .out(dataF3),
        .en(~stallD),
        .flush(flushD)
    );

    decode decode_inst(
        .dataF3(dataF3),
        .dataD(dataD_nxt)
        // .jr_ra_fail
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

    bypass_input_t [1:0]dataE_in,dataM1_in,dataM2_in,dataM3_in;
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
        .dataM3_in,
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

        assign dataM2_in[i].data=dataM2[i].alu_out;
        assign dataM2_in[i].rdst=dataM2[i].rdst;
        assign dataM2_in[i].memtoreg=dataM2[i].ctl.memtoreg;
        assign dataM2_in[i].lotoreg=dataM2[i].ctl.lotoreg;
        assign dataM2_in[i].hitoreg=dataM2[i].ctl.hitoreg;
        assign dataM2_in[i].cp0toreg=dataM2[i].ctl.cp0toreg;
        assign dataM2_in[i].regwrite=dataM2[i].ctl.regwrite;

        assign dataM3_in[i].data=dataW[i].wd;
        assign dataM3_in[i].rdst=dataM3[i].rdst;
        assign dataM3_in[i].memtoreg=dataM3[i].ctl.memtoreg;
        assign dataM3_in[i].lotoreg=dataM3[i].ctl.lotoreg;
        assign dataM3_in[i].hitoreg=dataM3[i].ctl.hitoreg;
        assign dataM3_in[i].cp0toreg=dataM3[i].ctl.cp0toreg;
        assign dataM3_in[i].regwrite=dataM3[i].ctl.regwrite;

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

// u1 req1_finish,req2_finish;
//     always_ff @(posedge clk) begin
//         if (resetn) begin
//             if (((dreq[0].valid&&~dresp[0].addr_ok) && dresp[1].addr_ok)) begin
//                 req1_finish <= '1;
//             end
//             else if (dresp[0].addr_ok) begin
//                 req1_finish <= '0;
//             end
//         end else begin
//             req1_finish <= '0;
//         end   
//     end

//     //如果没有。
//     always_ff @(posedge clk) begin
//         if (resetn) begin
//             if ((dreq[1].valid&&~dresp[1].addr_ok) && dresp[0].addr_ok) begin
//                 req2_finish <= '1;
//             end
//             else if (dresp[1].addr_ok) begin
//                 req2_finish <= '0;
//             end
//         end 
//         else begin
//             req2_finish <= '0;
//         end   
//     end

    memory memory(
		.dataE(dataE),
		.dataE2(dataM1_nxt),
		.dreq,
        // .req_finish('0),
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

    assign dataM2_nxt[1]=dataM1[1];
    assign dataM2_nxt[0]=dataM1[0];

    pipereg2 #(.T(execute_data_t)) M2M3reg(
		.clk,.reset,
		.in(dataM2_nxt),
		.out(dataM2),
		.en('1),
		.flush(flushM3)
	);
	
	memory3 memory3(
        .clk,
		.dataE(dataM2),
		.dataM(dataM3_nxt),
		.dresp,
        .dreq,
        .resetn
	);

	pipereg2 #(.T(memory_data_t)) M3Wreg(
		.clk,.reset,
		.in(dataM3_nxt),
		.out(dataM3),
		.en(1'b1),
		.flush(flushW)
	);

    // cp0_regs_t regs_out ;

    writeback writeback(
        // .clk,.reset,
        .dataM(dataM3),
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
            if (dataM3[i].ctl.hiwrite) begin
                hi_data=dataM3[i].ctl.op==MTHI? dataM3[i].srca:dataM3[i].hilo[63:32];
                valid_j=i[0];
            end 
            if (dataM3[i].ctl.lowrite) begin
                lo_data=dataM3[i].ctl.op==MTLO? dataM3[i].srca:dataM3[i].hilo[31:0];
                valid_k=i[0];
            end
        end
    end
    word_t hi_rd,lo_rd;
    hilo hilo(
    .clk,.reset,
    .hi(hi_rd), .lo(lo_rd),
    .hi_write(dataM3[1].ctl.hiwrite||dataM3[0].ctl.hiwrite), .lo_write(dataM3[1].ctl.lowrite||dataM3[0].ctl.lowrite),
    .hi_data , .lo_data
    );
    
    u1 valid_i,valid_m,valid_n;
    assign valid_i= dataM3[1].ctl.cp0toreg;
    assign valid_m= dataM3[1].ctl.cp0write;
    assign valid_n=dataM3[1].cp0_ctl.ctype==EXCEPTION||dataM3[1].cp0_ctl.ctype==ERET;
    assign is_eret=dataM3[1].cp0_ctl.ctype==ERET || dataM3[0].cp0_ctl.ctype==ERET;
    word_t cp0_rd;

//   assign dataM3_save1.pc=dataM3[1].pc;
//   assign dataM3_save1.valid=dataM3[1].valid;
//   assign dataM3_save1.is_slot=dataM3[1].is_slot;
//   assign dataM3_save1.jump=dataM3[1].ctl.branch||dataM3[1].ctl.jump;
//   assign dataM3_save2.pc=dataM3[0].pc;
//   assign dataM3_save2.valid=dataM3[0].valid;
//   assign dataM3_save2.is_slot=dataM3[0].is_slot;
//   assign dataM3_save2.jump=dataM3[0].ctl.branch||dataM3[0].ctl.jump;
   u1 inter_valid;

	assign inter_valid=~i_wait&&dataM3[1].valid;
    cp0 cp0(
        .clk,.reset,
        .ra(dataM3[valid_i].cp0ra),//直接读写的指令一次发射一条
        .wa(dataM3[valid_m].cp0ra),
        .wd(dataM3[valid_m].srcb),
        .rd(cp0_rd),
        .epc,
        .valid(dataM3[valid_m].ctl.cp0write),
        .is_eret,
        .vaddr(dataM3[valid_n].cp0_ctl.vaddr),
        .ctype(dataM3[valid_n].cp0_ctl.ctype),
        .pc(dataM3[valid_n].pc),
        .etype(dataM3[valid_n].cp0_ctl.etype),
        .ext_int,
        .is_slot(dataM3[valid_n].is_slot),
        .is_INTEXC,
        .inter_valid,
        .is_EXC,
        .int_pc(dataM3[1].pc)
        // .pc_valid(dataM3[valid_n].valid)
        // .dataM3_save({dataM3_save1,dataM3_save2})
    );

endmodule

`endif