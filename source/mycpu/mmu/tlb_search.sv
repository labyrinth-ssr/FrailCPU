`ifndef __TLB_SEARCH_SV
`define __TLB_SEARCH_SV

`include "common.svh"

module tlb_search (
    input tlb_t tlb_ram,

    input logic [18:0] vpn2,
    input logic odd_page,
    input logic [7:0] asid,

    output tlb_search_t search_result 
);

    logic [`TLB_NUM-1:0] search_match;
    tlb_entry_t choose_entry;
    tlb_index_t choose_index;

    for (genvar i = 0; i < `TLB_NUM; i++) begin
        assign search_match[i] = (vpn2==tlb_ram[i].vpn2) & (asid==tlb_ram[i].asid|tlb_ram[i].G);
    end
    assign search_result.found = |search_match;
    always_comb begin
        choose_index = 0;
        for (int i = 0; i < `TLB_NUM; i++) begin
            choose_index |= search_match[i] ? tlb_index_t'(i) : 0;
        end
    end
    assign search_result.index = choose_index;
    
    assign choose_entry = tlb_ram[choose_index];

    assign search_result.pfn = odd_page ? choose_entry.pfn1 : choose_entry.pfn0;
    assign search_result.C = odd_page ? choose_entry.C1 : choose_entry.C0;
    assign search_result.D = odd_page ? choose_entry.D1 : choose_entry.D0;
    assign search_result.V = odd_page ? choose_entry.V1 : choose_entry.V0;


endmodule

`endif

