`ifndef __DIRECT_TRANSLATOR
`define __DIRECT_TRANSLATOR

`include "common.svh"

module direct_translator (
    input addr_t vaddr,
    input logic [2:0] config_k0,
    output addr_t paddr,
    output logic is_uncached
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

    assign is_uncached = vaddr[31:29] == 3'b101 | (vaddr[31:29] == 3'b100 & config_k0 != 3'b011);

endmodule

`endif



