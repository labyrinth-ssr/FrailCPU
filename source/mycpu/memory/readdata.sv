`ifndef __READDATA_SV
`define __READDATA_SV

`ifdef VERILATOR
`include "common.svh"
`include "pipes.svh"

`endif 

module readdata
(
    input word_t _rd,
    output word_t rd,
    input u2 addr,
    input msize_t msize,
    input u1 mem_unsigned,
	input misalign_mem_t memtype,
	input word_t original
	// input 
);
	u1 sign_bit;
	// u1 load_misalign;
	always_comb begin
		rd = 'x;
		sign_bit = 'x;
		// load_misalign='0;
		unique case(msize)
			MSIZE1: begin // LB, LBU
				unique case(addr)
					2'b00: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[7];
						rd = {{24{sign_bit}}, _rd[7-:8]};
					end
					2'b01: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[15];
						rd = {{24{sign_bit}}, _rd[15-:8]};
					end
					2'b10: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[23];
						rd = {{24{sign_bit}}, _rd[23-:8]};
					end
					2'b11: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[31];
						rd = {{24{sign_bit}}, _rd[31-:8]};
					end
					
					default: begin
						// load_misalign='1;
						
					end
				endcase
			end
			MSIZE2: begin
				unique case(addr)
					2'b00: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[15];
						rd = {{16{sign_bit}}, _rd[15-:16]};
					end
					2'b10: begin
						sign_bit = mem_unsigned ? 1'b0 : _rd[31];
						rd = {{16{sign_bit}}, _rd[31-:16]};
					end
					default: begin
						// load_misalign='1;
						
					end
				endcase
			end
			MSIZE4: begin
				unique case(memtype)
					MEML:begin
						unique case(addr)
							2'b00: begin
								rd = {_rd[7:0], original[23:0]};
							end
							2'b01: begin
								rd = {_rd[15:0], original[15:0]};
							end
							2'b10: begin
								rd = {_rd[23:0], original[7:0]};
							end
							2'b11: begin
								rd = _rd;
							end
							default: begin
								
							end
                		endcase
					end
					MEMR:begin
						unique case(addr)
							2'b00: begin
								rd = _rd;
							end
							2'b01: begin
								rd = {original[31:24], _rd[31:8]};
							end
							2'b10: begin
								rd = {original[31:16], _rd[31:16]};
							end
							2'b11: begin
								rd = {original[31:8], _rd[31:24]};
							end
							default: begin
								
							end
						endcase
					end
					NO_MISALIGN:begin
						rd =  _rd;
					end
					default:;
				endcase
			end
			default: ;
		endcase
	end
endmodule


`endif