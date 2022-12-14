`ifndef __CP0_SV
`define __CP0_SV

`ifdef VERILATOR
`include "common.svh"
`include "cp0_pkg.svh"
`include "mmu_pkg.svh"
`else
`endif

module cp0
	(
	input logic clk, reset,
	input u8 ra,wa,
	input u8 raM,
	input word_t wd,
	output word_t rd,
	output word_t rdM,
	output word_t epc,
	input u1 valid,is_eret,
	input word_t vaddr,
	output cp0_regs_t regs_out,
	input word_t pc,
	input excp_type_t etype,
	input cp0_type_t ctype,
	input u1 inter_valid,
	input u6 ext_int,
	input u1 is_slot,
	output is_INTEXC,
	output is_EXC,
	input word_t int_pc,
	input tlb_exc_t i_tlb_exc,
	input tlb_exc_t d_tlb_exc,
	input u1 d_write,
	input tlb_type_t tlb_type,
	input mmu_resp_t mmu_resp,
	output word_t entrance,
	output u1 is_int,
	input u1 int_slot
	// input dataM2_save_t dataM2_save[1:0]
);
	u1 double;
	cp0_regs_t regs, regs_nxt;
	assign regs_out=regs;
	// word_t offset;
	// assign entrance=regs.ebase+offset;

	word_t offset;
	assign entrance=32'hbfc00200+offset;
	always_comb begin
		offset=32'h180;
		if (is_int&&regs.cause.iv) begin
			offset=32'h200;
		end else if ((i_tlb_exc.refill||d_tlb_exc.refill)&&~regs.status.exl) begin
			offset=32'h0;
		end
	end

	// dataM2_save_t data_save[1:0];
	// assign regs_out=regs_nxt;
	// u1 trint,swint,exint;
	//异常，排除中断
	u1 interrupt;
	assign is_EXC= ctype==EXCEPTION;
	word_t pc1_save,pc2_save;
	
	// always_ff @(posedge clk) begin
	// 	for (int i=0; i<2; ++i) begin
	// 		if(dataM2_save[i].valid) begin
	// 			data_save[i]<=dataM2_save[i];
	// 		end
	// 	end
	// end
	assign is_int=interrupt||int_saved;

	typedef struct packed {
		word_t pc;
		u1 is_slot;
	} int_save_t;
	int_save_t int_save;
	u1 int_saved;
	// word_t soft_int_pc,soft_int_pc_nxt;

	// write
	always_ff @(posedge clk) begin
		if (reset) begin
			int_saved<='0;
		end else if (interrupt&&~inter_valid) begin
			// int_save.pc<=pc;
			// int_save.is_slot<=is_slot;
			int_saved<='1;
		end else if (inter_valid) begin
			// int_save<='0;
			int_saved<='0;
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			regs <= '0;
			regs.config0<=32'h80000483;
			regs.config1<=32'h20291480;
			regs.prid<=32'h00004220;
			regs.ebase.one<='1;
			// soft_int_pc<='0;
			// regs.mcause[1] <= 1'b1;
			// regs.epc[31] <= 1'b1;
		end else begin
			regs <= regs_nxt;
			double <= 1'b1-double;
			// soft_int_pc<=soft_int_pc_nxt;

		end
	end

	always_comb begin
		rd = '0;
		if (ra[2:0]==3'b0) begin
			unique case(ra[7:3])
			5'd0:  rd = regs.index;
			5'd1:  rd = regs.random;
			5'd2:  rd = regs.entry_lo0;
			5'd3:  rd = regs.entry_lo1;
			5'd4:  rd = regs.context_;
			5'd5:  rd = regs.page_mask;
			5'd6:  rd = regs.wired;
			// 5'd7:  rd = regs.reserved7;
			5'd8:  rd = regs.bad_vaddr;
			5'd9:  rd = regs.count;
			5'd10: rd = regs.entry_hi;
			5'd11: rd = regs.compare;
			5'd12: rd = regs.status;
			5'd13: rd = regs.cause;
			5'd14: rd = regs.epc;
			5'd15: rd = 32'h00004220;
			5'd16: rd = {28'h8000048,1'b0,regs.config0[2:0]};
			5'd30: rd = regs.error_epc;
			default: rd = '0;
		endcase
		end else if (ra[2:0]==3'b001) begin
			unique case(ra[7:3])
			5'd15: rd=  {2'b10,regs.ebase.ebase,12'b0};
			5'd16: rd = 32'h20291480;
			default:;

			endcase
		end
	end

		always_comb begin
		rdM = '0;
		if (raM[2:0]==3'b0) begin
			unique case(raM[7:3])
			5'd0:  rdM = regs.index;
			5'd1:  rdM = regs.random;
			5'd2:  rdM = regs.entry_lo0;
			5'd3:  rdM = regs.entry_lo1;
			5'd4:  rdM = regs.context_;
			5'd5:  rdM = regs.page_mask;
			5'd6:  rdM = regs.wired;
			// 5'd7:  rdM = regs.reserved7;
			5'd8:  rdM = regs.bad_vaddr;
			5'd9:  rdM = regs.count;
			5'd10: rdM = regs.entry_hi;
			5'd11: rdM = regs.compare;
			5'd12: rdM = regs.status;
			5'd13: rdM = regs.cause;
			5'd14: rdM = regs.epc;
			5'd15: rdM = 32'h00004220;
			5'd16: rdM = {28'h8000048,1'b0,regs.config0[2:0]};
			5'd30: rdM = regs.error_epc;
			default: rdM = '0;
		endcase
		end else if (raM[2:0]==3'b001) begin
			unique case(raM[7:3])
			5'd15: rdM=  {2'b10,regs.ebase.ebase,12'b0};
			5'd16: rdM = 32'h20291480;
			default:;

			endcase
		end
	end
		
	// write
	u5 code;
	always_comb begin
		code='0;
		if (interrupt) begin
			code=EXCCODE_INT;
		end else if (etype.badVaddrF) begin
			code=EXCCODE_ADEL;
		end else if (etype.reserveInstr) begin
			code=EXCCODE_RI;
		end else if (i_tlb_exc.refill||i_tlb_exc.invalid) begin
			code=EXCCODE_TLBL;
		end else if (etype.overflow) begin
			code=EXCCODE_OV;
		end else if (etype.bp) begin
			code=EXCCODE_BP;
		end else if (etype.syscall) begin
			code=EXCCODE_SYS;
		end else if (d_tlb_exc.refill||d_tlb_exc.invalid||d_tlb_exc.modified) begin
			code=d_tlb_exc.modified||d_write? EXCCODE_TLBS: EXCCODE_TLBL;
		end else if (etype.adelD) begin
			code=EXCCODE_ADEL;
		end else if (etype.adesD) begin
			code=EXCCODE_ADES;
		end else if (etype.cpU) begin
			code=EXCCODE_CPU;
		end else if (etype.trap) begin
			code=EXCCODE_TR;
		end
	end
	u1 soft_int;
	assign interrupt=regs.status.ie&&~regs.status.exl&&(|(({ext_int, 2'b00} | regs.cause.ip| {regs.cause.ti, 7'b0}) & regs.status.im));
	assign soft_int= |(regs.cause.ip[1:0] & regs.status.im[1:0]);
	// assign counter_int= regs_nxt.cause.ti & regs.status.im [7];
	// word_t int_pc;


	always_comb begin
		regs_nxt.cause.ti= regs.count==regs.compare;
		regs_nxt = regs;
		// soft_int_pc_nxt=soft_int_pc;
		if (double&&wa[7:3]!=5'd9) begin
			regs_nxt.count = regs.count + 1;
		end

		if ((interrupt||int_saved)&&inter_valid) begin
			regs_nxt.cause.exc_code=EXCCODE_INT;
			if (~regs.status.exl) begin
				if (~int_slot) begin
					regs_nxt.epc=int_pc;
					regs_nxt.cause.bd='0;
				end else begin
					regs_nxt.epc=int_pc-4;
					regs_nxt.cause.bd='1;
				end
			end
		regs_nxt.status.exl='1;
			
		end else if (ctype==EXCEPTION) begin
			if ((code==EXCCODE_ADEL&&etype.badVaddrF)||(code==EXCCODE_TLBL&&|i_tlb_exc)) begin
				regs_nxt.bad_vaddr=pc;
			end else if ((code==EXCCODE_ADEL&&etype.adelD)||code==EXCCODE_ADES||code==EXCCODE_TLBS||(code==EXCCODE_TLBL&&|d_tlb_exc)) begin
				regs_nxt.bad_vaddr=vaddr;
			end


			if (i_tlb_exc.refill||i_tlb_exc.invalid) begin
				regs_nxt.entry_hi.vpn2=pc[31:13];
			end else if (d_tlb_exc.refill||d_tlb_exc.invalid||d_tlb_exc.modified) begin
				regs_nxt.entry_hi.vpn2=vaddr[31:13];
			end

			regs_nxt.cause.exc_code=code;
			if (~regs.status.exl) begin
				if (~is_slot) begin
					regs_nxt.epc= pc;
					regs_nxt.cause.bd='0;
				end else begin
					regs_nxt.epc=pc-4;
					regs_nxt.cause.bd='1;
				end
			end
			regs_nxt.status.exl='1;
		end else if (valid) begin
			if (wa[2:0]==3'b0) begin
				case (wa[7:3])
					5'd0:  regs_nxt.index = wd;
					// 5'd1:  regs_nxt.random=wd;
					5'd2:  regs_nxt.entry_lo0[29:0] = wd[29:0];
					5'd3:  regs_nxt.entry_lo1[29:0] = wd[29:0];
					5'd4:  regs_nxt.context_[31:23] = wd[31:23];
					5'd5:  regs_nxt.page_mask=wd;
					5'd6:  regs_nxt.wired = wd;
					// 5'd7:  regs_nxt.reserved7=wd;
					5'd9:  regs_nxt.count = wd;
					5'd10: begin
						regs_nxt.entry_hi[31:13] = wd[31:13];
						regs_nxt.entry_hi[7:0] = wd[7:0];
					end
					5'd11: regs_nxt.compare = wd;
					5'd12: begin
						regs_nxt.status.cu0 = wd[28];
						regs_nxt.status.bev = wd[22];
						regs_nxt.status.im = wd[15:8];
						regs_nxt.status.um = wd[4];
						regs_nxt.status[2:0] = wd[2:0]; // ERL/EXL/IE
					end
					5'd13: begin
						regs_nxt.cause.iv = wd[23];
						regs_nxt.cause.ip[1:0] = wd[9:8];
						// soft_int_pc_nxt=pc;
					end
					5'd14: regs_nxt.epc = wd;
					// 5'd15: regs_nxt.prid=wd;
					5'd16: regs_nxt.config0[2:0] = wd[2:0];
					5'd28: regs_nxt.tag_lo=wd;
					5'd30: regs_nxt.error_epc=wd;
					// 5'd33: regs_nxt.ebase=wd;
					default:;
				endcase
			end else if (wa[2:0]==3'b001) begin
					case (wa[7:3])
						5'd15:regs_nxt.ebase.ebase=wd[29:12];
						default:;
					endcase
			end
		end else begin
			case(tlb_type)
				TLBP:begin
					regs_nxt.index=mmu_resp.index;
				end
				TLBR:begin
					regs_nxt.entry_hi=mmu_resp.entry_hi;
					regs_nxt.entry_lo0=mmu_resp.entry_lo0;
					regs_nxt.entry_lo1=mmu_resp.entry_lo1;
				end
				default:;
			endcase
		end
		
		if (is_eret) begin
			regs_nxt.status.exl='0;
		end 
	end
	assign epc = regs.epc;
	assign is_INTEXC= ctype==EXCEPTION||((interrupt||int_saved) &&inter_valid);

	
endmodule

`endif