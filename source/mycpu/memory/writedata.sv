`ifndef __WRITEDATA_SV
`define __WRITEDATA_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`include "pipes.svh"
`endif 

module writedata
(
    input u2 addr,
    input word_t _wd,
    input msize_t msize,
    output word_t wd,
    output strobe_t strobe,
	input misalign_mem_t memtype

);
always_comb begin
		strobe = '0;
		wd = '0;
		unique case(msize)
			MSIZE1: begin
				unique case(addr)
					2'b00: begin
						wd[7-:8] = _wd[7:0];
						strobe = 4'h01;
					end
					2'b01: begin
						wd[15-:8] = _wd[7:0];
						strobe = 4'h02;
					end
					2'b10: begin
						wd[23-:8] = _wd[7:0];
						strobe = 4'h04;
					end
					2'b11: begin
						wd[31-:8] = _wd[7:0];
						strobe = 4'h08;
					end
					default: begin
					end
				endcase
			end
			MSIZE2: begin
				unique case(addr)
					2'b00: begin
						wd[15-:16] = _wd[15:0];
						strobe = 4'h03;
					end
					2'b10: begin
						wd[31-:16] = _wd[15:0];
						strobe = 4'h0c;
					end
					default: begin
						
					end
				endcase
			end
			MSIZE4: begin
				unique case(memtype)
					MEML:begin
						unique case(addr)
							2'b00: begin
								wd = {24'b0, _wd[31:24]};
								strobe = 4'b0001;
							end
							2'b01: begin
								wd = {16'b0, _wd[31:16]};
								strobe = 4'b0011;
							end
							2'b10: begin
								wd = {8'b0, _wd[31:8]};
								strobe = 4'b0111;
							end
							2'b11: begin
								wd = _wd;
								strobe = 4'b1111;
							end
							default: begin
								
							end
						endcase
					end
					MEMR:begin
						unique case(addr)
							2'b00: begin
								wd = _wd;
								strobe = 4'b1111;

							end
							2'b01: begin
								wd = {_wd[23:0], 8'b0};
								strobe = 4'b1110;

							end
							2'b10: begin
								wd = {_wd[15:0], 16'b0};
								strobe = 4'b1100;

							end
							2'b11: begin
								wd = {_wd[7:0], 24'b0};
								strobe = 4'b1000;

							end
							default: begin
								
							end
						endcase
					end
					default:begin
						wd[31-:32] = _wd[31:0];
						strobe = 4'h0f;
					end
				endcase
			end
			default: begin
				
			end
		endcase
	end
endmodule
`endif
