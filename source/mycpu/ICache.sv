`include "common.svh"

import common::*;

module ICache (
    input logic clk, resetn,

    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp
);
    // simply use DCache as a ICache
    DCache proxy(.dreq({ireq, 4'b0, 32'b0}), .dresp(iresp), .*);
endmodule
