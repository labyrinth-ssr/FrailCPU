`ifndef __REGFILE_SV
`define __REGFILE_SV
`ifdef VERILATOR
`include "common.svh"
`else

`endif
module regfile 
	#(
	parameter READ_PORTS = 2,
	parameter WRITE_PORTS = 2
) (
	input logic clk, reset,
	input creg_addr_t [READ_PORTS-1:0] ra1, ra2,
	output word_t [READ_PORTS-1:0] rd1, rd2,
	input creg_addr_t [WRITE_PORTS-1:0] wa,
	input u1 [WRITE_PORTS-1:0] wvalid,
	input word_t [WRITE_PORTS-1:0] wd
);
	word_t [31:0] regs, regs_nxt;

	assign regs_nxt[0]='0;

	for (genvar i = 0; i < READ_PORTS; i++) begin
		assign rd1[i] = regs[ra1[i]];
		assign rd2[i] = regs[ra2[i]];
	end

	always_ff @(posedge clk) begin
		if (reset) begin
			regs <= '0;
		end else begin
			regs <= regs_nxt;
			regs[0] <= '0;
		end
	end
	
	for (genvar i = 1; i < 32; i++) begin
		always_comb begin
			regs_nxt[i] = regs[i];
			for (int j = 0; j < WRITE_PORTS; j++) begin
				if (i == wa[j] && wvalid[j]) begin
					regs_nxt[i] = wd[j];
				end
			end
		end
	end

endmodule

`endif