`ifndef __JHT_SV
`define __JHT_SV

`include "common.svh"
`include "test.svh"
`ifdef VERILATOR
`include "../plru.sv"
`endif 

module jht#(
    parameter int ASSOCIATIVITY = 2,
    parameter int SET_NUM = 8,

    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam TAG_BITS = 18,
    localparam type tag_t = logic [TAG_BITS-1:0],
    localparam type index_t = logic [INDEX_BITS-1:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0],
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type meta_t = struct packed {
        logic valid;
        tag_t tag;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    }
) (
    input logic clk, resetn,
    input logic is_write, // if this instr write in to jht (j, jal)
    input addr_t j_pc, executed_j_pc, dest_pc,
    /*
    * j_pc is the pc of the jump to be predicted(from f1)
    * executed_j_pc is the pc of the jump to be executed(from exe)
    * dest_pc is the branch dest of the executed_branch
    */
    output addr_t predict_pc,
    output logic hit, hit_pc, hit_pcp4
);

    function tag_t get_tag(addr_t addr);
        return addr[2+TAG_BITS-1:2];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1+5:2+5];
    endfunction

    meta_t [ASSOCIATIVITY-1:0] r_meta_hit;
    meta_t [ASSOCIATIVITY-1:0] r_meta_in_jht;
    meta_t [ASSOCIATIVITY-1:0] w_meta;
    addr_t r_pc_predict, r_pc_replace, w_pc_replace;
    associativity_t pc_hit_line, pcp4_hit_line, hit_line, replace_line;
    ram_addr_t predict_addr, replace_addr;
    logic in_jht, pc_hit, pcp4_hit;

    // for predict

    always_comb begin
        pc_hit = 1'b0;
        pc_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(j_pc))) begin
                pc_hit  = 1'b1;
                pc_hit_line = associativity_t'(i);
            end
        end 
    end

    always_comb begin
        pcp4_hit = 1'b0;
        pcp4_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_hit[i].valid && (r_meta_hit[i].tag == get_tag(j_pc+4))) begin
                pcp4_hit = 1'b1;
                pcp4_hit_line = associativity_t'(i);
            end
        end 
    end

    assign hit_pc = pc_hit;
    assign hit_pcp4 = pcp4_hit;
    assign hit = pcp4_hit | pc_hit;
    always_comb begin : hit_line_b
        hit_line = '0;
        if(pc_hit) hit_line = pc_hit_line;
        else if(pcp4_hit) hit_line = pcp4_hit_line;
    end

    assign predict_addr.index = get_index(j_pc);
    assign predict_addr.line = hit_line;

    assign predict_pc = hit ? r_pc_predict : '0;


    // for repalce

    always_comb begin
        in_jht = 1'b0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_meta_in_jht[i].valid && r_meta_in_jht[i].tag == get_tag(executed_j_pc)) begin
                in_jht = 1'b1;
            end
        end 
    end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r, plru_new;

    assign plru_r = plru_ram[get_index(j_pc)];

    assign replace_line[0] = plru_r[0];
    assign plru_new[0] = ~hit_line[0];

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[get_index(j_pc)] <= plru_new;
        end
    end

    assign replace_addr.line = replace_line;
    assign replace_addr.index = get_index(executed_j_pc);

    assign w_pc_replace = (~in_jht && is_write) ? dest_pc : r_pc_replace;

    always_comb begin : w_meta_b
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (~in_jht && is_write && associativity_t'(i) == replace_line) begin
                w_meta[i].valid = 1'b1;
                w_meta[i].tag = get_tag(executed_j_pc);
            end else begin
                w_meta[i] = r_meta_in_jht[i];
            end
        end 
    end

    ram_addr_t reset_addr;

    always_ff @( posedge clk ) begin : reset
        reset_addr <= reset_addr + 1;
    end



    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk),

        .en_1(1'b1), //port1 for replace
        .addr_1(resetn ? replace_addr.index : reset_addr.index),
        .rdata_1(r_meta_in_jht),
        .strobe(1'b1),  
        .wdata(resetn ? w_meta : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(j_pc)),
        .rdata_2(r_meta_hit)
    );

    LUTRAM_DualPort #(
        .ADDR_WIDTH($bits(ram_addr_t)),
        .DATA_WIDTH($bits(addr_t)),
        .BYTE_WIDTH($bits(addr_t)),
        .READ_LATENCY(0)
    ) dest_pc_ram(
        .clk(clk),

        .en_1(in_jht | is_write | ~resetn), //port1 for replace
        .addr_1(resetn ? replace_addr : reset_addr),
        .rdata_1(r_pc_replace),
        .strobe(1'b1),  
        .wdata(resetn ? w_pc_replace : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(predict_addr),
        .rdata_2(r_pc_predict)
    );

endmodule


`endif 