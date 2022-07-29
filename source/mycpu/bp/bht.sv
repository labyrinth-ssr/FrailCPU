`ifndef __BHT_SV
`define __BHT_SV

`include "common.svh"
`include "plru.sv"

module BHT#(
    parameter int ASSOCIATIVITY = 8,
    parameter int SET_NUM = 8,

    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam TAG_BITS = 30 - INDEX_BITS,
    localparam type tag_t = logic [TAG_BITS-1:0],
    localparam type index_t = logic [INDEX_BITS-1:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0],
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type meta_t = struct packed {
        logic valid;
        logic is_jump;
        tag_t tag;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    }
) (
    input logic clk, resetn,
    input logic is_write, // if this instr write in to bht (branch, j, jal)
    input logic is_jump_in, // if executed_branch is a jump(from exe)
    input addr_t branch_pc, executed_branch_pc, dest_pc,
    /*
    * branch_pc is the pc of the branch to be predicted(from f1)
    * executed_branch_pc is the pc of the branch to be executed(from exe)
    * dest_pc is the branch dest of the executed_branch
    */
    output addr_t predict_pc,
    output logic hit, is_jump_out
);

    function tag_t get_tag(addr_t addr);
        return addr[32:2+INDEX_BITS];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1:2];
    endfunction

    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_bht;
    meta_t [ASSOCIATIVITY-1:0] w_meta;
    addr_t r_pc_predict, r_pc_replace, w_pc_replace;
    associativity_t hit_line, replace_line;
    ram_addr_t predict_addr, replace_addr;
    // logic in_bht;

    // for predict

    always_comb begin
        hit = 1'b0;
        hit_line = '0;
        is_jump_out = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && r_meta_hit[i].tag == get_tag(branch_pc)) begin
                hit = 1'b1;
                hit_line = associativity_t'(i);
                is_jump_out = r_meta_hit[i].is_jump;
            end
        end 
    end

    assign predict_addr.line = hit_line;
    assign predict_addr.index = get_index(branch_pc);

    assign predict_pc = hit ? r_pc_predict : '0;

    // for repalce

    // always_comb begin
    //     in_bht = 1'b0;
    //     for (int i = 0; i < ASSOCIATIVITY; i++) begin
    //         if (r_meta_in_bht[i].valid && r_meta_in_bht[i].tag == get_tag(executed_branch_pc)) begin
    //             in_bht = 1'b1;
    //         end
    //     end 
    // end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r, plru_new;

    assign plru_r = plru_ram[predict_addr.index];

    plru port_1_plru(
        .plru_old(plru_r),
        .hit_line(hit_line),
        .plru_new(plru_new),
        .replace_line(replace_line)
    );

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[predict_addr.index] <= plru_new;
        end
    end

    assign replace_addr.line = replace_line;
    assign replace_addr.index = get_index(executed_branch_pc);

    assign w_pc_replace = /*~in_bht &&*/ is_write ? dest_pc : r_pc_replace;

    always_comb begin
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (/*~in_bht &&*/ is_write && i == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].is_jump = is_jump_in;
                w_meta[i].tag = get_tag(executed_branch_pc);
            end else begin
                w_meta[i] = r_meta_in_bht[i];
            end
        end 
    end



    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk),
        .resetn,

        .en_1(1'b1), //port1 for replace
        .addr_1(replace_addr.index),
        .rdata_1(r_meta_in_bht),
        .strobe(1'b1),  
        .wdata(w_meta),

        .en_2(1'b0), //port2 for predict
        .addr_2(predict_addr.index),
        .rdata_2(r_meta_hit)
    );

    LUTRAM_DualPort #(
        .ADDR_WIDTH($bits(ram_addr_t)),
        .DATA_WIDTH(32),
        .BYTE_WIDTH(32),
        .READ_LATENCY(0)
    ) dest_pc_ram(
        .clk(clk),
        .resetn, 

        .en_1(1'b1), //port1 for replace
        .addr_1(replace_addr),
        .rdata_1(r_pc_replace),
        .strobe(1'b1),  
        .wdata(w_pc_replace),

        .en_2(1'b0), //port2 for predict
        .addr_2(predict_addr),
        .rdata_2(r_pc_predict)
    );

endmodule


`endif 
