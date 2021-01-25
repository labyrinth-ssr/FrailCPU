`include "common.svh"

import common::*;

module IBusToCBus (
    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);
    // since IBus is a subset of DBus, we can reuse DBusToCBus.
    DBusToCBus inst(
        .dreq({ireq, 4'b0, 32'b0}),
        .dresp(iresp),
        .dcreq(icreq),
        .dcresp(icresp)
    );
endmodule
