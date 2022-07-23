`ifndef __IREQ_INTERFACE_SV
`define __IREQ_INTERFACE_SV

`include "common.svh"

module ireq_interface(
    input logic clk, resetn,
    input ibus_req_t _ireq,
    output cbus_req_t ireq_1, ireq_2,

    input cbus_resp_t iresp_1, iresp_2,// 32 bits data
    output ibus_resp_t _iresp// 64 bits data, {iresp2.data, iresp1.data}
);
    u1 req1_finish,req2_finish;
    assign ireq_1.valid = req1_finish? '0:_ireq.valid;
    assign ireq_1.addr = _ireq.addr;
    assign ireq_1.is_write = 0;  
    assign ireq_1.size = MSIZE4;         
    assign ireq_1.strobe = 0;   
    assign ireq_1.data = 0;      
    assign ireq_1.len = MLEN1;  

    always_ff @(posedge clk) begin
        if (ireq_1.valid&&iresp_1.last) begin
            req1_finish<='1;
        end else if (req1_finish&&ireq_2.valid) begin
            req1_finish<='1;
        end else begin
            req1_finish<='0;
        end
    end

    always_ff @(posedge clk) begin
        if (ireq_2.valid&&iresp_2.last) begin
            req2_finish<='1;
        end else begin
            req2_finish<='0;
        end
    end


    assign ireq_2.valid = req2_finish? '0:_ireq.valid;
    assign ireq_2.addr = _ireq.addr + 4;
    assign ireq_2.is_write = 0;  
    assign ireq_2.size = MSIZE4;         
    assign ireq_2.strobe = 0;   
    assign ireq_2.data = 0;      
    assign ireq_2.len = MLEN1;

    assign _iresp.data_ok = _ireq.valid ? (state == 2'b10) : 1'b0;
    assign _iresp.addr_ok = _ireq.valid ? (state == 2'b10) : 1'b0;
    assign _iresp.data = data;

    i64 data,data_nxt;
    i2 state, state_nxt;

    always_comb begin : gen_statenxt
        if(~_ireq.valid||req2_finish) 
            state_nxt = 2'b00;
        else
            state_nxt = state;
            if(iresp_1.last) state_nxt = state + 1;
            else if(iresp_2.last) state_nxt = state + 1;
    end

    always_comb begin : gen_datanxt
        if(~_ireq.valid) 
            data_nxt = '0;
        else begin
            data_nxt = data;
            if(iresp_1.last)
                data_nxt = {data[63:32], iresp_1.data};
            else if(iresp_2.last)
                data_nxt = {iresp_2.data, data[31:0]};
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn) begin//reset, we set all counter 2'b11
            data <= '0;
            state <= 2'b00;
        end else begin
            data <= data_nxt;
            state <= state_nxt;
        end
    end


endmodule


`endif 
