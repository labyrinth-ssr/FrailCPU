`include "common.svh"

module AddressTranslator (
    input  cbus_req_t  treq,
    output cbus_resp_t tresp,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);
    always_comb begin
        oreq = treq;

        /**
         * direct mapping:
         * 8 (1000) -> 0000
         * 9 (1001) -> 0001
         * A (1010) -> 0000
         * B (1011) -> 0001
         */
        oreq.addr = {3'b0, treq.addr[28:0]};
    end

    assign tresp = oresp;
endmodule
