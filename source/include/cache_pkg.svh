`ifndef __CACHE_PKG
`define __CACHE_PKG

`ifdef VERILATOR
`include "common.svh"
`endif


typedef enum logic [2:0] {
	I_UNKNOWN,
	I_INDEX_INVALID,
	I_INDEX_STORE_TAG,
	I_HIT_INVALID
} icache_inst_t;

typedef enum logic [2:0]  {
	D_UNKNOWN,
	D_INDEX_WRITEBACK_INVALID,
	D_INDEX_STORE_TAG,
	D_HIT_INVALID,
	D_HIT_WRITEBACK_INVALID
 } dcache_inst_t;

typedef enum logic [2:0] {
	NULL,
	REQ,
	INVALID,
	WRITEBACK_INVALID,
	INDEX_STORE
} cache_oper_t;

 `endif