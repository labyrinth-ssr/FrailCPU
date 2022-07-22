`ifndef __CP0_PKG_SV
`define __CP0_PKG_SV

`ifdef VERILATOR
`include "common.svh"
`endif

parameter EXCCODE_INT = 5'h0;
parameter EXCCODE_ADEL = 5'h4;
parameter EXCCODE_ADES = 5'h5;
parameter EXCCODE_SYS = 5'h8;
parameter EXCCODE_BP = 5'h9;
parameter EXCCODE_RI = 5'ha;
parameter EXCCODE_OV = 5'hc;

typedef enum u3 { 
	NO_EXC,EXCEPTION,INTERUPT,ERET,INSTR
 } cp0_type_t;

typedef struct packed {
	u1 badVaddrF,reserveInstr,overflow,trap,syscall,adelD,adesD;
} excp_type_t;

typedef struct packed {
	cp0_type_t ctype;
	excp_type_t etype;
	u1 valid;
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
	u32 ebase, config1;
	/* The order of the following registers is important.
	 * DO NOT change them. New registers must be added 
	 * BEFORE this comment */
	/* primary 32 registers (sel = 0) */
	u32 
	 desave,    error_epc,  tag_hi,     tag_lo,    
	 cache_err, err_ctl,    perf_cnt,   depc,      
	 debug,     impl_lfsr32,  reserved21, reserved20,
	 watch_hi,  watch_lo,   ll_addr,    config0,   
	 prid,      epc;
	cp0_cause_t  cause;
	cp0_status_t status;
	u32
	 compare,   entry_hi,   count,      bad_vaddr, 
	 reserved7, wired,      page_mask,  context_,  
	 entry_lo1, entry_lo0,  random,     index;
} cp0_regs_t;
	

`endif
