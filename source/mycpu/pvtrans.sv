`ifndef __PVTRANS_SV
`define __PVTRANS_SV

`ifdef VERILATOR
`include "common.svh"
`endif 

module pvtrans(
    input word_t vaddr,
    output word_t paddr
);
    assign paddr[27:0] = vaddr[27:0];

    always_comb begin
        unique case (vaddr[31:28])
            4'h8: paddr[31:28] = 4'b0; // kseg0
            4'h9: paddr[31:28] = 4'b1; // kseg0
            4'ha: paddr[31:28] = 4'b0; // kseg1
            4'hb: paddr[31:28] = 4'b1; // kseg1
            default: paddr[31:28] = vaddr[31:28]; // useg, ksseg, kseg3
        endcase
    end
endmodule


`endif