`ifndef __CP0_SV
`define __CP0_SV

`ifdef VERILATOR
`include "common.sv"
`include "cp0_pkg.sv"
`else
`endif

module cp0
	import cp0_pkg::*;(
	input logic clk, reset,
	input u8 ra,wa,
	input word_t wd,
	output word_t rd,
	output word_t epc,
	input u1 valid,is_eret,
	output cp0_regs_t regs_out,
	input word_t pc,
	input excp_type_t etype,
	input cp0_type_t ctype,
	input u1 inter_valid,
	output u1 interrupt_valid,
	input u5 ext_int,
	input u1 is_slot,is_INTEXC
);
	u1 double;
	cp0_regs_t regs, regs_nxt;
	assign regs_out=regs_nxt;
	u1 trint,swint,exint;
	u1 interrupt,delayed_interupt;
	assign is_INTEXC= ctype==EXCEPTION||(interrupt&&inter_valid)||delayed_interupt;

	typedef struct packed {
		word_t pc;
		u1 is_slot;
	} int_save_t;
	int_save_t int_save;
	u1 int_saved;
	// write
	always_ff @(posedge clk) begin
		if (interrupt&&~inter_valid&&~int_saved) begin
			int_save.pc<=pc;
			int_save.is_slot<=is_slot;
			int_saved<='1;
		end else if (inter_valid) begin
			int_save<='0;
			int_saved<='0;
		end
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			regs <= '0;
			regs.mcause[1] <= 1'b1;
			regs.epc[31] <= 1'b1;
		end else begin
			regs <= regs_nxt;
			double <= 1'b1-double;
		end
	end

	always_comb begin
		rd = '0;
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
			5'd15: rd = regs.prid;
			5'd16: rd = regs.config0;
			default: rd = '0;
		endcase
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
		end else if (etype.overflow) begin
			code=EXCCODE_OV;
		end else if (etype.trap) begin
			code=EXCCODE_BP;
		end else if (etype.syscall) begin
			code=EXCCODE_SYS;
		end else if (etype.adelD) begin
			code=EXCCODE_ADEL;
		end else if (etype.adesD) begin
			code=EXCCODE_ADES;
		end
	end

	assign interrupt=regs.status.ie&&~regs.status.exl&&(({ext_int, 2'b00} | regs.cause.ip | {regs.cause.ti, 7'b0}) & regs.status.im);

	assign regs.cause.ti= regs.count==regs.compare;
	always_comb begin
		regs_nxt = regs;
		delayed_interupt='0;
		if (double&&wa!=5'd9) begin
			regs_nxt.count = regs.count + 1;
		end

		if (ctype==EXCEPTION||(interrupt&&inter_valid&&~int_saved)) begin
					if (etype.badVaddrF&&code==EXCCODE_ADEL) begin
						regs_nxt.bad_vaddr=pc;
					end
					if (~regs.status.exl) begin
						if (~is_slot) begin
							regs_nxt.epc=pc;
							regs_nxt.cause.bd='0;
						end else begin
							regs_nxt.epc=pc-4;
							regs_nxt.cause.bd='1;
						end
					end
					regs_nxt.status.exl='1;
		end  else if (int_saved&&inter_valid) begin
					if (~regs.status.exl) begin
						if (~is_slot) begin
							regs_nxt.epc=pc;
							regs_nxt.cause.bd='0;
						end else begin
							regs_nxt.epc=pc-4;
							regs_nxt.cause.bd='1;
						end
					end
					regs_nxt.status.exl='1;
					delayed_interupt='1;
				end
				 else if (valid) begin
					case (wa)
						5'd0:  regs_nxt.index = wdata;
						// 5'd1:  regs_nxt.random=wdata;
						5'd2:  regs_nxt.entry_lo0 = wdata[29:0];
						5'd3:  regs_nxt.entry_lo1 = wdata[29:0];
						5'd4:  regs_nxt.context_[31:23] = wdata[31:23];
						5'd5:  regs_nxt.page_mask=wdata;
						5'd6:  regs_nxt.wired = wdata;
						// 5'd7:  regs_nxt.reserved7=wdata;
						5'd9:  regs_nxt.count = wdata;
						5'd10: begin
							regs_nxt.entry_hi[31:13] = wdata[31:13];
							regs_nxt.entry_hi[7:0] = wdata[7:0];
						end
						5'd11: regs_nxt.compare = wdata;
						5'd12: begin
							regs_nxt.status.cu0 = wdata[28];
							regs_nxt.status.bev = wdata[22];
							regs_nxt.status.im = wdata[15:8];
							regs_nxt.status.um = wdata[4];
							regs_nxt.status[2:0] = wdata[2:0]; // ERL/EXL/IE
						end
						5'd13: begin
							regs_nxt.cause.iv = wdata[23];
							regs_nxt.cause.ip[1:0] = wdata[9:8];
						end
						5'd14: regs_nxt.epc = wdata;
						// 5'd15: regs_nxt.prid=wdata;
						5'd16: regs_nxt.config0[2:0] = wdata[2:0];
					endcase
			// regs_nxt.mstatus.sd = regs_nxt.mstatus.fs != 0;
		end else if (is_eret) begin
			regs_nxt.status.exl='0;
		end 
	end
	assign epc = regs.epc;
	
endmodule

`endif