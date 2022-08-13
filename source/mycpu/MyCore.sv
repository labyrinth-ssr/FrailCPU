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
`include "bypassI.sv"
`include "bypassE.sv"
`include "bypassM.sv"
`include "hazard.sv"
// `include "pvtrans.sv"
`include "bpu.sv"
`endif 


module MyCore (
    input logic clk, resetn,

    output ibus_req_t [1:0] p_ireq,
    input  ibus_resp_t iresp,

    output dbus_req_t [1:0]  p_dreq,
    output logic [1:0] d_uncache,
    input  dbus_resp_t dresp,

    input logic [5:0] ext_int,

    output icache_inst_t icache_inst,
    output dcache_inst_t dcache_inst,

    output word_t tag_lo
);
    /**
     * TODO (Lab1) your code here :)
     */
    // assign tag_lo='0;
    u3 config_k0;
    mmu_req_t mmu_req;
    mmu_resp_t mmu_resp;
    mmu_exc_out_t mmu_exc_out;

    dbus_req_t [1:0] dreq;
    ibus_req_t ireq;

    u1 i_tlb_exc_bit;
    assign i_tlb_exc_bit='1;
    
    u1 stallF,stallD,flushD,flushE,flushM,stallM,stallE,flushW,stallM2,flushF2,flushI,flush_que,stallF2,flushM2,stallI,stallI_de,flushM3,pred_flush_que;
    u1 is_eret;
    u1 i_wait;
    u1 d_wait;
    u1 e_wait;
    u1 is_INTEXC,is_EXC;
    word_t epc;
    u1 excpM,overflowI;
    u1 reset;
    writeback_data_t [1:0]dataW;
    u1 pc_except;
    word_t entrance;
    // u1 cache_instE;
    word_t pc_selected,pc_succ,dataP_pc;
    assign pc_except=dataP_pc[1:0]!=2'b00;
    // assign d_wait= (dreq[1].valid&& ~dresp[1].addr_ok)||(dreq[0].valid&& ~dresp[0].addr_ok);
    u1 pred_taken;
    word_t pre_pc;
    u1 jr_ra_fail;
    u1 is_jr_ra_issue;
    // assign is_jr_ra_issue=candidate1.ctl.op==JR&&candidate1.ra1==31&&~issue_en_1&&~jr_pred_finish&&~candidate2_invalid;
    // (dataD_nxt[1].ctl.op==JR&&dataD_nxt[1].ra1==31)||(dataD_nxt[0].ctl.op==JR&&dataD_nxt[0].ra1==31);
    u1 jrI;
    // assign jrI='0;

    // u1 save_slotD;
    // assign save_slotD=dataD_nxt[0].ctl.op==JR&&dataD_nxt[0].ra1==31;
    // logic dreq_valid;
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
		.stallF,.stallD,.flushD,.flushE,.flushM,.flushI,.flush_que,.i_wait,.d_wait,.stallM,.stallM2,.stallE,.branchM(dataE[1].branch_taken||dataE[1].ctl.cache_i||dataE[1].ctl.tlb||dataE[1].ctl.cache_d),.e_wait,.clk,.flushW,.excpW(is_eret||is_INTEXC),.stallF2,.flushF2,.stallI,.flushM2,.overflowI,.stallI_de,.excpM,.reset,.jrI,.flushM3,.pred_flush_que,.waitM(dataE[1].ctl.wait_signal)
	);

    // word_t icache_addr_save;
    // u1 icache_addr_saved;

    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         {icache_addr_save,icache_addr_saved}<='0;
    //     end else if (dataE[1].ctl.cache_i&&i_wait) begin
    //         icache_addr_save<=dataE[1].cache_addr;
    //         icache_addr_saved<='1;
    //     end else if (~i_wait) begin
    //         {icache_addr_save,icache_addr_saved}<='0;
    //     end
    // end
    // // u1 i_wait_copy;
    // // assign 
    // always_comb begin
    //     ireq.addr=dataP_pc;
    //     if (icache_addr_saved) begin
    //         ireq.addr=icache_addr_save;
    //     end else if(~iresp.addr_ok&&dataE[1].ctl.cache_i) begin
    //         ireq.addr=dataE[1].cache_addr;
    //     end
    // end

    assign ireq.addr= dataP_pc;
	assign ireq.valid=  dataE[1].ctl.cache_i||~pc_except /*|| is_eret||is_EXC || excpM*/;
    assign reset=~resetn;

    fetch_data_t [1:0] dataF2_nxt ;
    fetch_data_t [1:0] dataF2 ;
    decode_data_t [1:0] dataD_nxt ,dataD ;
    issue_data_t [1:0] dataI_nxt,dataI;
    execute_data_t [1:0] dataE_nxt,dataE;
    execute_data_t [1:0] dataM1_nxt,dataM1;
    execute_data_t [1:0] dataM2_nxt,dataM2;
    memory_data_t [1:0] dataM3_nxt;
    memory_data_t [1:0] dataM3;
    assign icache_inst = dataM1[1].cache_ctl.icache_inst;
    assign dcache_inst = dataE[1].cache_ctl.dcache_inst;
    // always_comb begin
    assign pc_succ=dataP_pc+8;
    // word_t pc_save,icache_addr_save;
    // u1 pc_saved,icache_addr_saved;
    // // word_t jpc_save,ipc_save,jrpc_save,icache_addr_save;
    // word_t pc_nxt;
    // // u1 jpc_saved,ipc_saved,jrpc_saved,icache_addr_saved;
    // u1 forward_pc;
    // //icache，且无stallF时，存下一条
    // //icache且有stallF时，存两条
    // assign forward_pc=is_INTEXC|is_eret|dataE[1].branch_taken|dataE[1].ctl.cache|dataE[1].ctl.tlb;
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         // {jpc_save,ipc_save,jrpc_save,jpc_saved,ipc_saved,jrpc_saved}<='0;
    //         {pc_save,pc_saved}<='0;
    //     end else if (stallF&&(is_INTEXC||is_eret)) begin
	// 		pc_save<=pc_selected;
	// 		pc_saved<='1;
    //     end else if (stallF && (dataE[1].branch_taken||dataE[1].ctl.cache_d||dataE[1].ctl.tlb) ) begin
    //         pc_save<=pc_selected;
    //         pc_saved<='1;
    //     end else if (dataE[1].ctl.cache_i ) begin
    //         if (stallF) begin
    //             icache_addr_save<=dataE[1].cache_addr;
    //             icache_addr_saved<='1;
    //         end
    //         pc_save<=dataE[1].target;
    //         pc_saved<='1;
    //     end else if (stallF && jrI) begin
    //         pc_save<=pc_selected;
    //         pc_saved<='1;
    //     end else if (~stallF) begin
    //         if (~icache_addr_saved) begin
    //             pc_save<='0;
    //             pc_saved<='0;
    //         end
    //         {icache_addr_save,icache_addr_saved}<='0;
	// 	end
	// end

    // always_comb begin
    //     if (pc_saved) begin
    //         pc_nxt=pc_save;
    //     end else if (icache_addr_saved&&~is_INTEXC&&~is_eret) begin
    //         pc_nxt=icache_addr_save;
    //     end 
    //     // else if (jpc_saved&&~is_INTEXC&&~is_eret) begin
    //     //     pc_nxt=jpc_save;
    //     // end else if (jrpc_saved&&~(dataE[1].branch_taken||dataE[1].ctl.cache_i||dataE[1].ctl.cache_d||dataE[1].ctl.tlb)&&~is_INTEXC) begin
    //     //     pc_nxt=jrpc_save;
    //     // end 
    //     else begin
    //         pc_nxt=pc_selected;
    //     end
    // end

    

    word_t jpc_save,ipc_save,jrpc_save,icache_addr_save;
    word_t pc_nxt;
    u1 jpc_saved,ipc_saved,jrpc_saved,icache_addr_saved;
    always_ff @(posedge clk) begin
        if (reset) begin
            {jpc_save,ipc_save,jrpc_save,jpc_saved,ipc_saved,jrpc_saved}<='0;
        end else if (stallF&&(is_INTEXC||is_eret)) begin
			ipc_save<=pc_selected;
			ipc_saved<='1;
        end else if (stallF && (dataE[1].branch_taken||dataE[1].ctl.cache_d||dataE[1].ctl.tlb) ) begin
            jpc_save<=pc_selected;
            jpc_saved<='1;
        end else if (dataE[1].ctl.cache_i ) begin
            if (stallF) begin
                icache_addr_save<=dataE[1].cache_addr;
                icache_addr_saved<='1;
            end
            jpc_save<=dataE[1].target;
            jpc_saved<='1;
        end else if (stallF && jrI) begin
            jrpc_save<=pc_selected;
            jrpc_saved<='1;
        end else if (~stallF) begin
			ipc_save<='0;
			ipc_saved<='0;
            if (~icache_addr_saved) begin
                jpc_save<='0;
                jpc_saved<='0;
            end
            {icache_addr_save,icache_addr_saved}<='0;
            jrpc_save<='0;
			jrpc_saved<='0;
		end
	end

    always_comb begin
        if (ipc_saved) begin
            pc_nxt=ipc_save;
        end else if (icache_addr_saved&&~is_INTEXC&&~is_eret) begin
            pc_nxt=icache_addr_save;
        end else if (jpc_saved&&~is_INTEXC&&~is_eret) begin
            pc_nxt=jpc_save;
        end else if (jrpc_saved&&~(dataE[1].branch_taken||dataE[1].ctl.cache_i||dataE[1].ctl.cache_d||dataE[1].ctl.tlb)&&~is_INTEXC) begin
            pc_nxt=jrpc_save;
        end else begin
            pc_nxt=pc_selected;
        end
    end
    // u1 j_misalign_hazard;
    // u1 jr_pc_saved;
    // word_t jr_pc_save;
    // assign j_misalign_hazard= pred_taken&&hit_bit&&dataP_pc[2];pred_pc_saved,pred_pc_save,
    u1 zero_prej;
    u1 hit_bit;
    assign zero_prej=pred_taken&&~hit_bit;
    // u1 jrI_misalign;
    // assign jrI_misalign=jrI&&save_slotD;

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

    u1 valid_n;
    pcselect pcselect_inst (
        .pc_selected,
        .pc_succ,
        .pc_branch(dataE[1].target),
        .branch_taken(dataE[1].branch_taken||dataE[1].ctl.cache_i||dataE[1].ctl.cache_d||dataE[1].ctl.tlb),
        .epc,
        .icache(dataE[1].ctl.cache_i),
        .icache_addr(dataE[1].cache_addr),
        // .is_tlb_refill(dataM3[valid_n].i_tlb_exc.refill||dataM3[valid_n].d_tlb_exc.refill),
        .entrance,
		.is_eret,
		.is_INTEXC,
        .pred_taken(pred_taken&&~zero_prej),
        .pre_pc,
        .issue_taken(jrI),
        // .refetchD_pc(dataD_nxt[0].pc),
        // .select_refetchD(jrD_misalign),
        .zero_prej
        // .cache_instE
    );
    //pipereg between pcselect and fetch1
    fetch1_data_t dataF1_nxt,dataF1;
    assign dataF1_nxt.valid='1;
    assign dataF1_nxt.pc=dataP_pc;
    assign dataF1_nxt.cp0_ctl.ctype= pc_except||(|mmu_exc_out.i_tlb_exc[1]) ? EXCEPTION : NO_EXC;
    assign dataF1_nxt.cp0_ctl.exc_eret= pc_except;
    assign dataF1_nxt.pre_b= pred_taken&&~zero_prej;
    assign dataF1_nxt.pre_pc= pre_pc;
    assign dataF1_nxt.nxt_valid=~zero_prej;
    assign dataF1_nxt.nxt_exception=~(|mmu_exc_out.i_tlb_exc[1]) && (|mmu_exc_out.i_tlb_exc[0]);
    assign dataF1_nxt.i_tlb_exc= ~(|mmu_exc_out.i_tlb_exc[1])? mmu_exc_out.i_tlb_exc[0]:mmu_exc_out.i_tlb_exc[1];
    always_comb begin 
        dataF1_nxt.cp0_ctl.vaddr='0;
        dataF1_nxt.cp0_ctl.etype.badVaddrF=pc_except;
    end
    // assign dataF1_nxt.cp0_ctl.valid='0;
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
        .is_jr_ra_decode(is_jr_ra_issue),
        .jr_ra_fail,
        // .decode_ret_pc,
        // .decode_taken,//预测跳转
        .exe_pc(dataE[1].pc),
        .is_taken(dataE[1].branch_taken),
        .dest_pc(dataE[1].dest_pc),
        .ret_pc(dataE[1].pc+8),
        .is_jal(dataE[1].ctl.op==JAL),
        .is_jalr(dataE[1].ctl.op==JALR),
        .is_branch(dataE[1].ctl.branch),
        .is_j(dataE[1].ctl.op==J),
        .is_jr_ra_exe(dataE[1].is_jr_ra),
        .pos(hit_bit),
        .flush_ras(dataE[1].branch_taken)
    );


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
    u1 rawinstr_saved;
    u64  raw_instrf2_save;
    // tlb_exc_t [1:0] i_tlb_exc_save;
    // tlb_exc_t [1:0] selected_i_tlb_exc;
    // assign selected_i_tlb_exc=rawinstr_saved? i_tlb_exc_save:mmu_exc_out.i_tlb_exc;

    u1 delay_flushF2;
    always_ff @(posedge clk) begin
        if (reset) begin
            {raw_instrf2_save,rawinstr_saved,delay_flushF2}<='0;
        end else begin
            delay_flushF2 <=flushF2;
            if (stallF2&&~rawinstr_saved) begin
                raw_instrf2_save<=iresp.data;
                rawinstr_saved<='1;
                // i_tlb_exc_save<=mmu_exc_out.i_tlb_exc;
                
            end else if (~stallF2) begin
                {raw_instrf2_save,rawinstr_saved}<='0;
            end
        end
    end
    //前半部分静止，应当不发起ireq
    // u1 delay_save_slotD;
    // always_ff @(posedge clk) begin
    //     delay_save_slotD<=save_slotD;
    // end


    always_comb begin
        dataF2_nxt[1].raw_instr=  iresp.data[31:0];
        dataF2_nxt[1].i_tlb_exc= dataF1.nxt_exception? '0:dataF1.i_tlb_exc ;
        dataF2_nxt[1].cp0_ctl=dataF1.cp0_ctl;
        dataF2_nxt[1].cp0_ctl.ctype=dataF1.cp0_ctl.ctype;
        // dataF2_nxt[1].cp0_ctl.exc_eret= dataF1.cp0_ctl.exc_eret;
        if (dataF1.cp0_ctl.exc_eret) begin
            dataF2_nxt[1].raw_instr='0;
        end else if (rawinstr_saved) begin
            dataF2_nxt[1].raw_instr= raw_instrf2_save[31:0];
        end else if (delay_flushF2) begin
            dataF2_nxt[1].raw_instr='0;
        end
    end

    always_comb begin
        dataF2_nxt[0].raw_instr=  iresp.data[63:32];
        dataF2_nxt[0].i_tlb_exc=  dataF1.nxt_exception? dataF1.i_tlb_exc :'0;
        dataF2_nxt[0].cp0_ctl='0;
        dataF2_nxt[0].cp0_ctl.ctype=dataF1.nxt_exception? EXCEPTION:NO_EXC;
        if (dataF1.cp0_ctl.exc_eret) begin
            dataF2_nxt[0].raw_instr='0;
        end else if (rawinstr_saved) begin
            dataF2_nxt[0].raw_instr=raw_instrf2_save[63:32];
            // dataF2_nxt[0].i_tlb_exc= i_tlb_exc_save[0];
            // dataF2_nxt[0].cp0_ctl.ctype=|i_tlb_exc_save[0]? EXCEPTION:NO_EXC;
        end else if (delay_flushF2) begin
            dataF2_nxt[0].raw_instr='0;
            // dataF2_nxt[0].i_tlb_exc='0;
        end
    end

    assign dataF2_nxt[1].pc=dataF1.pc;
    assign dataF2_nxt[1].pre_b=dataF1.pre_b;
    assign dataF2_nxt[1].pre_pc=dataF1.pre_pc;
    assign dataF2_nxt[0].pre_b='0;
    assign dataF2_nxt[0].pre_pc='0;
    // assign dataF2_nxt[1].raw_instr=rawinstr_saved? raw_instrf2_save[31:0]:iresp.data[31:0];
    assign dataF2_nxt[1].valid= dataF1.valid;
    // for ( genvar i = 0; i<2; ++i) begin
        
    // end
    // assign dataF2_nxt[1].cp0_ctl=dataF1.cp0_ctl;
    // assign dataF2_nxt[0].cp0_ctl.ctype= ~i_tlb_exc_bit&&(|itlbex)

    assign dataF2_nxt[0].pc=dataF1.nxt_valid? dataF1.pc+4:'0;
    // assign dataF2_nxt[0].raw_instr=rawinstr_saved? raw_instrf2_save[63:32]:iresp.data[63:32];
    assign dataF2_nxt[0].valid=/*~pc_except&&*/dataF1.nxt_valid;


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



    u1 jr_pred_finish;
    decode_data_t candidate1;
    u1 issue_en_1;
    u1 candidate2_invalid;

    always_ff @(posedge clk) begin
        if (reset) begin
            jr_pred_finish<='0;
        end else if (candidate1.ctl.op==JR&&candidate1.ra1==31&&~candidate2_invalid&&~issue_en_1&&~(d_wait||e_wait)) begin
            jr_pred_finish<='1;
        end else if (issue_en_1) begin
            jr_pred_finish<='0;
        end
    end

    assign jrI=is_jr_ra_issue&&~jr_ra_fail;
    assign is_jr_ra_issue=candidate1.ctl.op==JR&&candidate1.ra1==31&&~jr_pred_finish&&~candidate2_invalid&&~issue_en_1&&~(d_wait||e_wait);

    u1 jr_predicted;
    word_t jr_predicted_pc;
    always_ff @(posedge clk) begin
        if (reset) begin
            jr_predicted<='0;
            jr_predicted_pc<='0;
        end else if (jrI) begin
            jr_predicted<='1;
            jr_predicted_pc<=pre_pc;
        end else if (issue_en_1) begin
            jr_predicted<='0;
            jr_predicted_pc<='0;
        end
    end

   

    bypass_input_t [1:0]dataE_in,dataM1_in,dataM2_in,dataM3_in;
    bypass_output_t [1:0]bypass_outra1 ,bypass_outra2 ,bypass_outra1E,bypass_outra2E;
    cp0_bypass_input_t [1:0]dataM1_inM,dataM2_inM,dataM3_inM;


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
        .stallI_de,
        .candidate1,
        .issue_en_1,
        .pred_flush_que,
        .candidate2_invalid,
        .jr_predicted,
        .jr_predicted_pc
    );

    bypass_issue_t [1:0] dataI_in,issue_bypass_out,dataE_nxt_in;
    assign dataI_in=issue_bypass_out;
    bypass_execute_t [1:0] dataEnxt_in;

    bypassI bypassI(
        .dataE_in,
        .dataM1_in,
        .dataM2_in,
        .dataI_in,
        .dataEnxt_in,
        .dataM3_in,
        .outra1(bypass_outra1),
        .outra2(bypass_outra2)
    );

    bypassE bypassE(
        .dataE_in,
        .dataM1_in,
        .dataM2_in,
        .dataE_nxt_in,
        .dataM3_in,
        .outra1(bypass_outra1E),
        .outra2(bypass_outra2E)
    );

    for (genvar i=0; i<2 ;++i) begin
        assign dataE_in[i].data=dataE[i].alu_out;
        assign dataE_in[i].rdst=dataE[i].rdst;
        assign dataE_in[i].memtoreg=dataE[i].ctl.memtoreg;
        assign dataE_in[i].lotoreg=dataE[i].ctl.lotoreg;
        assign dataE_in[i].hitoreg=dataE[i].ctl.hitoreg;
        assign dataE_in[i].cp0toreg=dataE[i].ctl.cp0toreg;
        assign dataE_in[i].regwrite=dataE[i].ctl.regwrite;
        assign dataE_in[i].mul=dataE[i].ctl.mul&&dataE[i].ctl.regwrite;

        assign dataM1_in[i].data=dataM1[i].alu_out;
        assign dataM1_in[i].rdst=dataM1[i].rdst;
        assign dataM1_in[i].memtoreg=dataM1[i].ctl.memtoreg;
        assign dataM1_in[i].lotoreg=dataM1[i].ctl.lotoreg;
        assign dataM1_in[i].hitoreg=dataM1[i].ctl.hitoreg;
        assign dataM1_in[i].cp0toreg=dataM1[i].ctl.cp0toreg;
        assign dataM1_in[i].regwrite=dataM1[i].ctl.regwrite;
        assign dataM1_in[i].mul=dataM1[i].ctl.mul&&dataM1[i].ctl.regwrite;

        assign dataM1_inM[i].cp0write=dataM1[i].ctl.cp0write;
        assign dataM1_inM[i].data=dataM1[i].srcb;
        assign dataM1_inM[i].cp0wa=dataM1[i].cp0ra;


        assign dataM2_in[i].data=dataM2[i].alu_out;
        assign dataM2_in[i].rdst=dataM2[i].rdst;
        assign dataM2_in[i].memtoreg=dataM2[i].ctl.memtoreg;
        assign dataM2_in[i].lotoreg=dataM2[i].ctl.lotoreg;
        assign dataM2_in[i].hitoreg=dataM2[i].ctl.hitoreg;
        assign dataM2_in[i].cp0toreg=dataM2[i].ctl.cp0toreg;
        assign dataM2_in[i].regwrite=dataM2[i].ctl.regwrite;
        assign dataM2_in[i].mul=dataM2[i].ctl.mul&&dataM2[i].ctl.regwrite;

        assign dataM2_inM[i].cp0write=dataM2[i].ctl.cp0write;
        assign dataM2_inM[i].cp0wa=dataM2[i].cp0ra;
        assign dataM2_inM[i].data=dataM2[i].srcb;


        assign dataM3_in[i].data=dataW[i].wd;
        assign dataM3_in[i].rdst=dataM3[i].rdst;
        assign dataM3_in[i].memtoreg=dataM3[i].ctl.memtoreg;
        assign dataM3_in[i].lotoreg=dataM3[i].ctl.lotoreg;
        assign dataM3_in[i].hitoreg=dataM3[i].ctl.hitoreg;
        assign dataM3_in[i].cp0toreg=dataM3[i].ctl.cp0toreg;
        assign dataM3_in[i].regwrite=dataM3[i].ctl.regwrite;
        assign dataM3_in[i].mul=dataM3[i].ctl.mul&&dataM3[i].ctl.regwrite;

        assign dataM3_inM[i].cp0write=dataM3[i].ctl.cp0write;
        assign dataM3_inM[i].cp0wa=dataM3[i].cp0ra;
        assign dataM3_inM[i].data=dataM3[i].srcb;


        assign dataEnxt_in[i].rdst=dataI[i].rdst;
        assign dataEnxt_in[i].regwrite=dataI[i].ctl.regwrite;
        assign dataEnxt_in[i].memtoreg=dataI[i].ctl.memtoreg;
        assign dataEnxt_in[i].hitoreg=dataI[i].ctl.hitoreg;
        assign dataEnxt_in[i].lotoreg=dataI[i].ctl.lotoreg;
        assign dataEnxt_in[i].cp0toreg=dataI[i].ctl.cp0toreg;
        assign dataEnxt_in[i].mul=dataI[i].ctl.mul&&dataI[i].ctl.regwrite;

        assign dataE_nxt_in[i].ra1=dataI[i].ra1;
        assign dataE_nxt_in[i].ra2=dataI[i].ra2;
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
        .e_wait,
        .bypass_inra1(bypass_outra1E),
        .bypass_inra2(bypass_outra2E),
        .d_wait
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
   bypass_output_t outcp0r;
   word_t cp0rdM;
//    word_t cp0rd;
   assign tag_lo=outcp0r.bypass? outcp0r.data:cp0rdM;

    // cp0_bypass_input_t [1:0] 
    
    // 28

    bypassM bypassM(
        .dataM1_in(dataM1_inM),
        .dataM2_in(dataM2_inM),
        .dataM3_in(dataM3_inM),
        .cp0ra(dataE[1].cp0ra),
        .outcp0r
    );



    memory memory(
		.dataE(dataE),
		.dataE2(dataM1_nxt),
		.dreq,
        .d_tlb_exc(mmu_exc_out.d_tlb_exc),
        // .bypass_input(cp0rd)
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
        // .d_tlb_exc(mmu_exc_out.d_tlb_exc)
	);

	pipereg2 #(.T(memory_data_t)) M3Wreg(
		.clk,.reset,
		.in(dataM3_nxt),
		.out(dataM3),
		.en(1'b1),
		.flush(flushW)
	);


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
    u1 hi_write,lo_write;
    u64 hilo_res;
    word_t hi_rd,lo_rd;

    //如果有两条连续的写，均以后一条的写入数据为准，若未两条连续的读，则内容恒定
    always_comb begin
        {hi_data,lo_data}='0;
        {valid_j,valid_k}='0;
        {hi_write,lo_write}='0;
        for (int i=1; i>=0; --i) begin
            if (dataM3[i].ctl.hiwrite) begin
                hi_write='1;
                hi_data=dataM3[i].ctl.op==MTHI? dataM3[i].srca:dataM3[i].hilo[63:32];
                unique case(dataM3[i].ctl.hilo_op)
                    HILO_ADD:begin
                        hilo_res={hi_rd,lo_rd}+dataM3[i].hilo;
                        hi_data=hilo_res[63:32];
                    end
                    HILO_SUB:begin
                        hilo_res={hi_rd,lo_rd}-dataM3[i].hilo;
                        hi_data=hilo_res[63:32];
                    end
                    default:;
                endcase
                valid_j=i[0];
            end 
            if (dataM3[i].ctl.lowrite) begin
                lo_write='1;
                lo_data=dataM3[i].ctl.op==MTLO? dataM3[i].srca:dataM3[i].hilo[31:0];
                unique case(dataM3[i].ctl.hilo_op)
                    HILO_ADD:begin
                        hilo_res={hi_rd,lo_rd}+dataM3[i].hilo;
                        lo_data=hilo_res[31:0];
                    end
                    HILO_SUB:begin
                        hilo_res={hi_rd,lo_rd}-dataM3[i].hilo;
                        lo_data=hilo_res[31:0];
                    end
                    default:;
                endcase
                valid_k=i[0];
            end
        end
    end
    // u1 hi_write

    // always_comb begin
        
    // end

    // assign hi_write=dataM3[]

    hilo hilo(
    .clk,.reset,
    .hi(hi_rd), .lo(lo_rd),
    .hi_write, .lo_write,
    .hi_data , .lo_data
    );
    
    u1 valid_i;
    assign valid_i= dataM3[1].ctl.cp0toreg;
    // assign valid_m= dataM3[1].ctl.cp0write;
    assign valid_n=dataM3[1].cp0_ctl.ctype==EXCEPTION||dataM3[1].cp0_ctl.ctype==ERET;
    assign is_eret=dataM3[1].cp0_ctl.ctype==ERET || dataM3[0].cp0_ctl.ctype==ERET;
    word_t cp0_rd;

    u1 inter_valid;
    cp0_regs_t regs_out ;

    word_t int_pc_save;
    u1 int_pc_saved;
    u1 int_slot;
	always_ff @(posedge clk) begin
		if (reset) begin
			int_pc_save<='0;
            int_pc_saved<='0;
            int_slot<='0;
		end else if (dataM3[0].valid&&is_int) begin
			int_pc_save<=dataM3[0].pc;
            int_pc_saved<='1;
            int_slot<=dataM3[0].is_slot;
        end else if (~dataM3[0].valid&&dataM3[1].valid&&is_int) begin
			int_pc_save<=dataM3[1].pc;
            int_pc_saved<='1;
            int_slot<='0;
        end else if (~is_int) begin
            int_pc_save<='0;
            int_pc_saved<='0;
            int_slot<='0;
        end
	end

    // word_t int_pc;
    // always_comb begin
    //     int_pc='0;
    //     priority case(1'b1)
    //         ~int_pc_saved&&inter_valid:begin
    //             int_pc=dataM3[0].valid? dataM3[0].pc:dataM3[1].pc;
    //         end
    //         int_pc_saved:begin
    //             int_pc=int_pc_save;
    //         end
            
    //         default:int_pc='0;
    //     endcase
    // end

	assign inter_valid=(~i_wait||dataE[1].ctl.wait_signal)&&int_pc_saved;
    u1 is_int;
    cp0 cp0(
        .clk,.reset,
        .raM(dataE[1].cp0ra),
        .rdM(cp0rdM),
        .ra(dataM3[valid_i].cp0ra),//直接读写的指令一次发射一条
        .wa(dataM3[1].cp0ra),
        .wd(dataM3[1].srcb),
        .rd(cp0_rd),
        .epc,
        .valid(dataM3[1].ctl.cp0write),
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
        .int_pc(int_pc_save),
        .regs_out,
        .i_tlb_exc(dataM3[valid_n].i_tlb_exc),
        .d_tlb_exc(dataM3[valid_n].d_tlb_exc),
        .d_write(dataM3[valid_n].ctl.memwrite),
        .tlb_type(dataM3[1].ctl.tlb_type),
        .mmu_resp,
        .entrance,
        .is_int,
        .int_slot
    );

    assign mmu_req.index=regs_out.index;
    assign mmu_req.entry_hi=regs_out.entry_hi;
    assign mmu_req.entry_lo0=regs_out.entry_lo0;
    assign mmu_req.entry_lo1=regs_out.entry_lo1;
    assign mmu_req.random=regs_out.random;

    assign mmu_req.is_tlbwi=dataM3[1].ctl.tlb_type==TLBWI;
    assign mmu_req.is_tlbwr=dataM3[1].ctl.tlb_type==TLBWR;

    // assign config_k0=regs_out.config0[2:0];
    assign config_k0=regs_out.config0[2:0];




    //ireq
    ibus_req_t [1:0] v_ireq;
    assign v_ireq[0] = ireq;
    always_comb begin
        v_ireq[1] = ireq;
        v_ireq[1].addr = ireq.addr + 4;
        v_ireq[1].valid = icache_inst==I_UNKNOWN & ireq.valid;
    end

    //dreq
    dbus_req_t [1:0] v_dreq;
    assign v_dreq[0] = dreq[1];
    always_comb begin
        v_dreq[1] = dreq[0];
        v_dreq[1].valid = dcache_inst==D_UNKNOWN & dreq[0].valid;
    end

    assign i_wait = p_ireq[0].valid & ~iresp.addr_ok;

    logic [1:0] i_uncache;

    mmu mmu (
        .clk,
        .resetn,

        .config_k0,

        //地址翻译 
        .v_ireq,
        .ireq(p_ireq),
        .v_dreq,
        .dreq(p_dreq),

        //uncache信号
        .i_uncache,
        .d_uncache,

        //TLB指令相关
        .mmu_in(mmu_req),
        .mmu_out(mmu_resp),

        //TLB例外
        .mmu_exc(mmu_exc_out)
    );

endmodule

`endif