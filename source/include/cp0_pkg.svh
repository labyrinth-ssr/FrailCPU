`ifndef __CP0_PKG_SV
`define __CP0_PKG_SV

`include "common.svh"
`ifdef VERILATOR
`include "common.svh"
`endif

parameter EXCCODE_INT = 5'h0;
parameter EXCCODE_MOD = 5'h01;
parameter EXCCODE_TLBL = 5'h02;
parameter EXCCODE_TLBS = 5'h03;
parameter EXCCODE_ADEL = 5'h4;
parameter EXCCODE_ADES = 5'h5;
parameter EXCCODE_SYS = 5'h8;
parameter EXCCODE_BP = 5'h9;
parameter EXCCODE_RI = 5'ha;
parameter EXCCODE_CPU = 5'hb;
parameter EXCCODE_OV = 5'hc;
parameter EXCCODE_TR = 5'hd;

`define TLB_NUM 16
`define TLB_INDEX_BIT $clog2(`TLB_NUM)

// typedef u32 cp0_taglo_t;

typedef struct packed {
    logic [5:0] zero;     
    logic [19:0] pfn;        
    logic [2:0] C;                  
    logic D;                       
    logic V;                        
    logic G;                        
} cp0_entrylo_t;

typedef struct packed {
    logic [18:0] vpn2;
    logic [4:0] zero;
    logic [7:0] asid;
} cp0_entryhi_t;

typedef struct packed {
    logic P;                    
    logic [30-`TLB_INDEX_BIT:0] zero;  
    logic [`TLB_INDEX_BIT-1:0] index; 
} cp0_index_t;

typedef struct packed {                 
    logic [31-`TLB_INDEX_BIT:0] zero;  
    logic [`TLB_INDEX_BIT-1:0] random; 
} cp0_random_t;

typedef struct packed {                 
    logic [31-`TLB_INDEX_BIT:0] zero;  
    logic [`TLB_INDEX_BIT-1:0] wired; 
} cp0_wired_t;

typedef struct packed {
	logic [2:0] zero_1;
	logic [15:0] mask;
	logic [12:0] zero;                
} cp0_pagemask_t;

typedef struct packed {
	logic one;
	logic zero_1;
	logic [17:0] ebase;
	logic [11:0] zero_2;               
} cp0_ebase_t;

typedef u32 cp0_taglo_t;

typedef enum u3 { 
	NO_EXC,EXCEPTION,INTERUPT,ERET,INSTR
 } cp0_type_t;

typedef struct packed {
	u1 badVaddrF,reserveInstr,overflow,trap,syscall,adelD,adesD,cpU,bp;
} excp_type_t;

typedef struct packed {
	u1 exc_eret;
	cp0_type_t ctype;
	excp_type_t etype;
	// word_t vaddr;
} cp0_control_t;

typedef struct packed {
	logic cu3, cu2, cu1, cu0;
	logic rp, fr, re, mx;
	logic px, bev, ts, sr;
	logic nmi, zero;
	logic [1:0] impl;
	logic [7:0] im;
	logic kx, sx, ux, um;
	logic r0, erl, exl, ie;
} cp0_status_t;

typedef struct packed {
	logic bd, ti;
	logic [1:0] ce;
	logic [3:0] zero27_24;
	logic iv, wp;
	logic [5:0] zero21_16;
	logic [7:0] ip;
	logic zero7;
	logic [4:0] exc_code;
	logic [1:0] zero1_0;
} cp0_cause_t;
	

typedef struct packed {
	cp0_ebase_t ebase; 
	u32 config1;
	/* The order of the following registers is important.
	 * DO NOT change them. New registers must be added 
	 * BEFORE this comment */
	/* primary 32 registers (sel = 0) */
	u32 desave, error_epc, tag_hi;     
	cp0_taglo_t tag_lo;

	u32 cache_err, err_ctl, perf_cnt, depc, debug, impl_lfsr32, reserved21, reserved20, watch_hi, watch_lo, ll_addr, config0, prid, epc;
	cp0_cause_t  cause;
	cp0_status_t status;
	u32 compare;   
	cp0_entryhi_t entry_hi;  
	u32 count, bad_vaddr, reserved7;
	cp0_wired_t wired;
	u32 page_mask;
	u32 context_;
	cp0_entrylo_t entry_lo1, entry_lo0;
	cp0_random_t random;     
	cp0_index_t index;
} cp0_regs_t;
	

`endif
