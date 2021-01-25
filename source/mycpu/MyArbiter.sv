`include "common.svh"

module MyArbiter #(
    parameter int NUM_INPUTS = 2
) (
    input  cbus_req_t  [NUM_INPUTS - 1:0] ireqs,
    output cbus_resp_t [NUM_INPUTS - 1:0] iresps,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    /**
     * TODO (Lab2) your code here :)
     */

    // remove following lines when you start
    assign iresps = '0;
    assign oreq = '0;
    logic _unused_ok = &{ireqs, oresp};
endmodule
