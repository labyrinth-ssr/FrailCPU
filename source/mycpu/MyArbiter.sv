`ifndef __MYARBITER_SV
`define __MYARBITER_SV

`include "common.svh"

module MyArbiter #(
    parameter int NUM_INPUTS = 2,

    localparam int MAX_INDEX = NUM_INPUTS - 1,
    localparam type index_t  = logic [$clog2(NUM_INPUTS)-1:0]
) (
    input logic clk, resetn,

    input  cbus_req_t  [MAX_INDEX:0] ireqs,
    output cbus_resp_t [MAX_INDEX:0] iresps,
    output cbus_req_t  oreq,
    input  cbus_resp_t oresp
);

    // logic busy;
    localparam type state_t = enum logic[1:0] {
        IDLE, BUSY, JUDGE
    };

    state_t state;
    index_t index, select;

    always_comb begin
        select = 0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            if (ireqs[i].valid) begin
                select = index_t'(i);
                break;
            end
        end
    end

    //FSM
    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case (state)
                IDLE: begin
                    state <= ireqs[select].valid ? BUSY : IDLE;
                    index <= select;
                end

                BUSY: begin
                    if (oresp.last) begin
                        state <= JUDGE;   
                    end
                end
                
                JUDGE: begin
                    state <= ireqs[select].valid ? BUSY : IDLE;
                    index <= select;
                end

                default: begin
                end
            endcase   
        end else begin
            state <= IDLE;
            index <= '0;
        end
    end
    
    //oreq
    always_comb begin
        oreq = '0;
        unique case (state)
            BUSY: begin
                oreq = ireqs[index];
            end
            JUDGE: begin
                oreq = ireqs[select];
            end
            default: begin
            end
        endcase
    end

    //iresps
    always_comb begin
        iresps = '0;
        for (int i = 0; i < NUM_INPUTS; i++) begin
            unique case (state)
                BUSY: begin
                    iresps[i] = (index == index_t'(i)) ? oresp : 0;
                end
                JUDGE: begin
                    iresps[i] = (select == index_t'(i)) ? oresp : 0;
                end
                default: begin
                end
            endcase    
        end
        
    end

endmodule

`endif 
