`ifndef __SRAMX_SVH__
`define __SRAMX_SVH__

typedef struct packed {
    logic        req;
    logic        wr;
    logic [1 :0] size;
    logic [31:0] addr;
    logic [31:0] wdata;
} sramx_req_t;

typedef struct packed {
    logic        addr_ok;
    logic        data_ok;
    logic [31:0] rdata;
} sramx_resp_t;

`endif
