`ifndef __MMU_PKG
`define __MMU_PKG

`ifdef VERILATOR
`include "common.svh"
`include "cp0_pkg.svh"
`endif

typedef struct packed {
    logic [18:0] vpn2;
    logic odd_page;
    logic [11:0] page_offset;    
} vaddr_t;

typedef struct packed {
    logic [19:0] pfn;
    logic [11:0] page_offset;    
} paddr_t;

typedef logic [`TLB_INDEX_BIT-1:0] tlb_index_t;

typedef struct packed {
    logic [18:0] vpn2;
    logic [7:0] asid;
    logic G;
    logic [19:0] pfn0;
    logic [2:0] C0;
    logic D0;
    logic V0;
    logic [19:0] pfn1;
    logic [2:0] C1;
    logic D1;
    logic V1;   
} tlb_entry_t;

typedef tlb_entry_t [`TLB_NUM-1:0] tlb_t;

typedef struct packed {
    logic found;
    tlb_index_t index;
    paddr_t paddr;
    logic [2:0] C;
    logic D;
    logic V;
} tlb_search_t;


typedef struct packed {
	logic is_tlbwi;
    logic is_tlbwr;

	cp0_entryhi_t entry_hi;
    cp0_entrylo_t entry_lo0;
	cp0_entrylo_t entry_lo1;
	cp0_index_t index;
    cp0_random_t random;
} mmu_req_t;
    
typedef struct packed {
	cp0_entryhi_t entry_hi;
    cp0_entrylo_t entry_lo0;
	cp0_entrylo_t entry_lo1;
	cp0_index_t index;
} mmu_resp_t;

typedef struct packed {
    logic refill;
	logic invalid; 
	logic modified; 
} tlb_exc_t;

typedef struct packed {
    tlb_exc_t i_tlb_exc;
    tlb_exc_t [1:0] d_tlb_exc;
} mmu_exc_out_t;



`endif
