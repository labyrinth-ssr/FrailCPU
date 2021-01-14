`include "Common.svh"

module IBusToCBus (
    input  ibus_req_t  ireq,
    output ibus_resp_t iresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp
);
    // since IBus is a subset of DBus, we can reuse DBusToCBus.
    DBusToCBus inst(
        .dreq({ireq, 4'b0, 32'b0}),
        .dresp(iresp),
        .*
    );
endmodule
