`ifndef __TWO_LEVEL_ADAPTIVE_BP_SV
`define __TWO_LEVEL_ADAPTIVE_BP_SV

`include "common.svh"

module TWO_LEVEL_ADAPTIVE_BP #(
    parameter int ENTRIES = 64,
    parameter int COUNTER_BITS = 2,

    localparam BH_BITS = $clog2(ENTRIES),
    localparam COUNTER_BITS = 2,
    localparam type counter_t = logic [COUNTER_BITS-1:0]
) (
    input logic clk, resetn,
    input logic is_taken, is_branch,
    /*
    * is_taken and is_branch is the input of the counter, they are signals from the stage we take branch (i.e. execute)
    */
    output logic [COUNTER_BITS-1:0] prediction_outcome//[1] == 0 is taken, [1] == 1 is not taken
);
    counter_t w_counter, r1_counter;
    logic [BH_BITS-1:0] bh_reg;
    logic [BH_BITS-1:0] bh_reg_nxt;

    always_comb begin : gen_bh_reg_nxt
        if(is_branch) begin
            bh_reg_nxt = {bh_reg[BH_BITS-2:0], is_taken}; // shift left
        end else begin
            bh_reg_nxt = bh_reg; //not branch, stay
        end
    end
    
    always_ff @(posedge clk) begin
        bh_reg <= bh_reg_nxt;
    end

    always_comb begin : gen_w_counter 
        if(~is_branch) w_counter = r1_counter;
        else begin
            unique case (r1_counter)
                2'b00: begin
                    if (is_taken) w_counter = 2'b00;
                    else w_counter = 2'b01;
                end

                2'b01: begin
                    if (is_taken) w_counter = 2'b00;
                    else w_counter = 2'b10;
                end
                
                2'b10: begin
                    if (is_taken) w_counter = 2'b01;
                    else w_counter = 2'b11;
                end

                2'b11: begin
                    if (is_taken) w_counter = 2'b10;
                    else w_counter = 2'b11;
                end

                default: begin   
                end
            endcase 
        end
    end

    LUTRAM_DualPort #(
        .ADDR_WIDTH(BH_BITS),
        .DATA_WIDTH(COUNTER_BITS),
        .BYTE_WIDTH(COUNTER_BITS),
        .READ_LATENCY(0)
    ) counter_ram(
        .clk(clk),
        .resetn,

        .en_1(1'b1), //port1 update the counter
        .addr_1(bh_reg_nxt),
        .rdata_1(r1_counter),
        .strobe(1'b1),  
        .wdata(w_counter),

        .en_2(1'b0), //port2 generate the prediction outcome
        .addr_2(bh_reg),
        .rdata_2(prediction_outcome)
    );

endmodule


`endif 
