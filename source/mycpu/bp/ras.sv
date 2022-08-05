`ifndef __RAS_SV
`define __RAS_SV

`include "common.svh"

module ras #(
    parameter int RAS_SIZE = 16,

    localparam RAS_ADDR_BITS = $clog2(RAS_SIZE),
    localparam type ras_addr_t = logic [RAS_ADDR_BITS-1:0]
) (
    input logic clk, resetn,
    input logic push, pop, flush_ras,
    input addr_t ret_pc_push,
    output addr_t ret_pc_pop, 
    output u1 fail
);
    ras_addr_t top, top_nxt, ras_addr;// top == '0 when stack_num == 1 or stack_num == 0
    logic empty, empty_nxt, overflow, overflow_nxt, full, fuck_high, fuck_high_nxt, fuck_low, fuck_low_nxt;// hope you won't see fuck == 1
    logic [RAS_SIZE-1:0] overflow_counter;
    logic [RAS_SIZE-1:0] overflow_counter_nxt;
    addr_t w_ret_pc, r_ret_pc;

    assign ret_pc_pop = r_ret_pc;
    assign fail = empty || overflow;

    assign full = &top;

    always_comb begin
        empty_nxt = empty;
        if(push) empty_nxt = 1'b0;
        else if(top == '0 && pop) empty_nxt = 1'b1;

    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            empty <= 1'b1;
        end else begin
            empty <= empty_nxt;
        end
    end

    always_comb begin
        overflow_nxt = overflow;
        if(push && full) overflow_nxt = 1'b1;
        else if(~(|overflow_counter)) overflow_nxt = 1'b0;
    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            overflow <= 1'b0;
        end else begin
            overflow <= overflow_nxt;
        end
    end

    always_comb begin
        top_nxt = top;
        if(push && ~full && ~empty) begin // push && top is not '1 && stack is not empty (when stack_num == 0 or stack_num == 1 top = 0)
            top_nxt = top + 1;
        end else if(pop && (|top) && ~overflow) begin // pop && top is not '0
            top_nxt = top - 1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            top <= '0;
        end else begin
            top <= top_nxt;
        end
    end

    always_comb begin
        overflow_counter_nxt = overflow_counter;
        if(full && push) begin
            overflow_counter_nxt = overflow_counter + 1;
        end else if((|overflow_counter) && pop) begin
            overflow_counter_nxt = overflow_counter - 1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            overflow_counter <= '0;
        end else begin
            overflow_counter <= overflow_counter_nxt;
        end
    end

    always_comb begin
        fuck_high_nxt = fuck_high;
        if((&overflow_counter) && push) begin
            fuck_high_nxt = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            fuck_high <= '0;
        end else begin
            fuck_high <= fuck_high_nxt;
        end
    end

    always_comb begin
        fuck_low_nxt = fuck_low;
        if(empty && pop) begin
            fuck_low_nxt = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if(~resetn | flush_ras) begin
            fuck_low <= '0;
        end else begin
            fuck_low <= fuck_low_nxt;
        end
    end

    always_comb begin
        ras_addr = top;
        if(push) begin
            ras_addr = top_nxt;
        end
    end

    always_comb begin
        w_ret_pc = r_ret_pc;
        if(push && ~full) begin
            w_ret_pc = ret_pc_push;
        end
    end

    RAM_SinglePort #(
		.ADDR_WIDTH(RAS_ADDR_BITS),//8 cache sets
		.DATA_WIDTH(32),
		.BYTE_WIDTH(32),
		.READ_LATENCY(0)
    ) ret_pc_ram (
        .clk(clk), .en(1'b1),
        .addr(ras_addr),//get meta from cache set[index]
        .strobe(1'b1),
        .wdata(w_ret_pc),
        .rdata(r_ret_pc)
    );

endmodule


`endif 