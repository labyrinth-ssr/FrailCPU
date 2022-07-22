`include "common.svh"

module MyArbiter #(
    parameter int NUM_INPUTS = 2,

    localparam int MAX_INDEX = NUM_INPUTS - 1
) (
    input  cbus_req_t  [MAX_INDEX:0] ireqs,
    output cbus_resp_t [MAX_INDEX:0] iresps,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);

    logic busy;
    logic index, select;

    assign oreq = busy ? ireqs[index] : '0;  // prevent early issue

    always_comb begin
        select = 0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (ireqs[i].valid) begin
                select = i;
                break;
            end
        end
    end

    // feedback to selected request
    always_comb begin
        iresps = '0;
        if (busy) begin
            iresps[index] = oresp;
        end
    end

    always_ff @(posedge clk)
    if (resetn) begin
        if (busy) begin
            if (oresp.last) begin
                if (ireqs[~select].valid) begin
                    index <= ~select;
                end
                else begin
                    busy <= '0;
                end
            end
        end else begin
            busy <= ireqs[select].valid;
            index <= select;
        end
    end else begin
        {busy, index} <= '0;
    end

endmodule
