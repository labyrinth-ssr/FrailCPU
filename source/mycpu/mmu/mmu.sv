`ifndef __MMU_SV
`define __MMU_SV

`include "common.svh"
`include "cp0_pkg.svh"
`include "mmu_pkg.svh"
`ifdef VERILATOR

`include "tlb_search.sv"
`include "tlb.sv"
`endif

//地址翻译 
//TLB指令执行: TLBR, TLBWI, TLBWR, TLBP
//TLB例外
module mmu (
    input logic clk,
    input logic resetn,

    input logic [2:0] config_k0,

    //地址翻译 
    input ibus_req_t [1:0] v_ireq,
    output ibus_req_t [1:0] ireq,
    input dbus_req_t [1:0] v_dreq,
    output dbus_req_t [1:0] dreq,

    //uncache信号
    output logic [1:0] i_uncache,
    output logic [1:0] d_uncache,

    //TLB指令相关
    input mmu_req_t mmu_in,
    output mmu_resp_t mmu_out,

    //TLB例外
    output mmu_exc_out_t mmu_exc   
);
    //mapped or unmapped
    function logic is_mapped(input vaddr_t vaddr);
        return (vaddr[31:30] == 2'b11 | vaddr[31] == 1'b0);
    endfunction

    //unmapped : translator
    function paddr_t unmapped_translator(input vaddr_t vaddr); 
        return {3'b0, vaddr[28:0]};
    endfunction

    //unmapped : uncache
    function logic unmapped_is_uncached(input vaddr_t vaddr); 
        return vaddr[31:29] == 3'b101 | (vaddr[31:29] == 3'b100 & config_k0 != 3'd3);
    endfunction


    //mapped : translator
    tlb_search_t [1:0] i_tlb_result;
    tlb_search_t [1:0] d_tlb_result;

    //TLBP
    tlb_search_t tlbp_result;
    assign mmu_out.index.P = ~tlbp_result.found;
    assign mmu_out.index.zero = '0;
	assign mmu_out.index.index = tlbp_result.index;

    //TLBWI, TLBWR
    tlb_index_t w_index;
    assign w_index = mmu_in.is_tlbwi ? mmu_in.index.index : mmu_in.random.random;

    tlb_entry_t w_entry;
    assign w_entry.vpn2 = mmu_in.entry_hi.vpn2;
    assign w_entry.asid = mmu_in.entry_hi.asid;
    assign w_entry.G = mmu_in.entry_lo0.G & mmu_in.entry_lo1.G;
    assign w_entry.pfn0 = mmu_in.entry_lo0.pfn;
    assign w_entry.C0 = mmu_in.entry_lo0.C;
    assign w_entry.D0 = mmu_in.entry_lo0.D;
    assign w_entry.V0 = mmu_in.entry_lo0.V;
    assign w_entry.pfn1 = mmu_in.entry_lo1.pfn;
    assign w_entry.C1 = mmu_in.entry_lo1.C;
    assign w_entry.D1 = mmu_in.entry_lo1.D;
    assign w_entry.V1 = mmu_in.entry_lo1.V;


    //TLBR
    tlb_index_t r_index;
    assign r_index = mmu_in.index.index;

    tlb_entry_t r_entry;

    assign mmu_out.entry_hi.vpn2 = r_entry.vpn2;
    assign mmu_out.entry_hi.zero = '0;
    assign mmu_out.entry_hi.asid = r_entry.asid;

    assign mmu_out.entry_lo0.zero = '0;
    assign mmu_out.entry_lo0.pfn = r_entry.pfn0;
    assign mmu_out.entry_lo0.G = r_entry.G;
    assign mmu_out.entry_lo0.C = r_entry.C0;
    assign mmu_out.entry_lo0.D = r_entry.D0;
    assign mmu_out.entry_lo0.V = r_entry.V0;

    assign mmu_out.entry_lo1.zero = '0;
    assign mmu_out.entry_lo1.pfn = r_entry.pfn1;
    assign mmu_out.entry_lo1.G = r_entry.G;
    assign mmu_out.entry_lo1.C = r_entry.C1;
    assign mmu_out.entry_lo1.D = r_entry.D1;
    assign mmu_out.entry_lo1.V = r_entry.V1;
    

    tlb tlb (
        .clk,
        .resetn,

        .asid(mmu_in.entry_hi.asid),

        .i_vaddr({v_ireq[1].addr, v_ireq[0].addr}),
        .i_search_result(i_tlb_result),
        .d_vaddr({v_dreq[1].addr, v_dreq[0].addr}),
        .d_search_result(d_tlb_result),

        .entry_hi(mmu_in.entry_hi),
        .tlbp_search_result(tlbp_result),

        .r_index,
        .r_entry,

        .we(mmu_in.is_tlbwi | mmu_in.is_tlbwr),
        .w_index,
        .w_entry
    );

    logic [1:0] i_is_mapped;
    paddr_t [1:0] i_paddr;
    logic [1:0] i_is_uncached;

    for (genvar i = 0; i < 2; i++) begin
        assign i_is_mapped[i] = is_mapped(v_ireq[i].addr);
        assign i_paddr[i] = i_is_mapped[i] ? i_tlb_result[i].paddr : unmapped_translator(v_ireq[i].addr);
        assign i_is_uncached[i] = unmapped_is_uncached(v_ireq[i].addr) | (i_is_mapped[i] & i_tlb_result[i].C != 3'd3);
    end

    logic [1:0] d_is_mapped;
    paddr_t [1:0] d_paddr;
    logic [1:0] d_is_uncached;

    for (genvar i = 0; i < 2; i++) begin
        assign d_is_mapped[i] = is_mapped(v_dreq[i].addr);
        assign d_paddr[i] = d_is_mapped[i] ? d_tlb_result[i].paddr : unmapped_translator(v_dreq[i].addr);
        assign d_is_uncached[i] = unmapped_is_uncached(v_dreq[i].addr) | (d_is_mapped[i] & d_tlb_result[i].C != 3'd3);
    end

    //ireq, dreq输出
    for (genvar i = 0; i < 2; i++) begin
        always_comb begin 
            ireq[i] = v_ireq[i];
            ireq[i].addr = i_paddr[i];
            ireq[i].valid = v_ireq[i].valid & ~(mmu_exc.i_tlb_exc[i].refill|mmu_exc.i_tlb_exc[i].invalid|mmu_exc.i_tlb_exc[i].modified);
        end
    end

    for (genvar i = 0; i < 2; i++) begin
        always_comb begin 
            dreq[i] = v_dreq[i];
            dreq[i].addr = d_paddr[i];
            dreq[i].valid = v_dreq[i].valid & ~(mmu_exc.d_tlb_exc[i].refill|mmu_exc.d_tlb_exc[i].invalid|mmu_exc.d_tlb_exc[i].modified);
        end
    end

    assign i_uncache = i_is_uncached;
    assign d_uncache = d_is_uncached;

    //TLB例外
    for (genvar i = 0; i < 2; i++) begin
        assign mmu_exc.i_tlb_exc[i].refill = v_ireq[i].valid & i_is_mapped[i] & ~i_tlb_result[i].found;
        assign mmu_exc.i_tlb_exc[i].invalid = v_ireq[i].valid & i_is_mapped[i] & i_tlb_result[i].found & ~i_tlb_result[i].V;
        assign mmu_exc.i_tlb_exc[i].modified = '0;
    end

    for (genvar i = 0; i < 2; i++) begin
        assign mmu_exc.d_tlb_exc[i].refill = v_dreq[i].valid & d_is_mapped[i] & ~d_tlb_result[i].found;
        assign mmu_exc.d_tlb_exc[i].invalid = v_dreq[i].valid & d_is_mapped[i] & d_tlb_result[i].found & ~d_tlb_result[i].V;
        assign mmu_exc.d_tlb_exc[i].modified = v_dreq[i].valid & d_is_mapped[i] & d_tlb_result[i].found & d_tlb_result[i].V & ~d_tlb_result[i].D & |v_dreq[i].strobe;
    end
    
	
	

    

    





endmodule

`endif
