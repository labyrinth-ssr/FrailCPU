`ifndef __WRITEDATA_SV
`define __WRITEDATA_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"
`endif 

module writedata
(
    input u2 addr,
    input word_t _wd,
    input msize_t msize,
    output word_t wd,
    output strobe_t strobe
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
				unique case(addr)
					2'b00: begin
						wd[31-:32] = _wd[31:0];
						strobe = 4'h0f;
					end
					default: begin
						
					end
				endcase
				
			end
			default: begin
				
			end
		endcase
	end
endmodule
`endif
