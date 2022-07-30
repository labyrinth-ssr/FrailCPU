`ifndef __CACHE_PKG
`define __CACHE_PKG

`ifdef VERILATOR
`include "common.svh"
`endif


typedef enum logic [2:0] {
	NULL,
	INDEX_INVALID,
	INDEX_STORE_TAG,
	HIT_INVALID
} icache_inst_t;

 typedef enum logic [2:0]  {
	NULL,
	INDEX_WRITEBACK_INVALID,
	INDEX_STORE_TAG,
	HIT_INVALID,
	HIT_WRITEBACK_INVALID
 } dcache_inst_t;


 `endif