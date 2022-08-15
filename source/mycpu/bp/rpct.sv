`ifndef __RPCT_SV
`define __RPCT_SV

`include "common.svh"


module rpct #(
    parameter int ASSOCIATIVITY = 2,
    parameter int SET_NUM = 8,
    parameter int TAG_BITS = 18,
    
    localparam INDEX_BITS = $clog2(SET_NUM),
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY),
    localparam type tag_t = logic [TAG_BITS-1:0],
    localparam type pchi_t = logic [30-TAG_BITS-1:0],
    localparam type index_t = logic [INDEX_BITS-1:0],
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0],
    localparam type plru_t = logic [ASSOCIATIVITY-2:0],
    localparam type meta_t = struct packed {
        logic valid;
        tag_t tag;
        pchi_t pchi;
    },
    localparam type ram_addr_t = struct packed {
        index_t index;
        associativity_t line;
    },
    localparam type meta_set_t = meta_t [ASSOCIATIVITY-1:0]
) (
    input logic clk, resetn,
    input logic is_call, // if this instr is jal or jalr
    input logic is_ret, //if this instr is jr (ra)
    input addr_t pc_f1, jrra_pc, call_pc, ret_pc,
    /*
    * pc_check is the pc to be predicted(from f1)
    * jrra_pc is the pc of the jr (ra) or jalr (from exe)
    */
    output logic hit, hit_pc, hit_pcp4,
    output addr_t pre_pc
);

    function tag_t get_tag(addr_t addr);
        return addr[2+TAG_BITS-1:2];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[2+INDEX_BITS-1+12:2+12];
    endfunction

    function pchi_t get_pchi(addr_t addr);
        return addr[31:TAG_BITS+2];
    endfunction

    meta_set_t jrra_pc_pre, ret_pc_pre;
    meta_set_t r_jrra_pc_re, w_jrra_pc_re, r_call_pc_re, w_call_pc_re, r_ret_pc_re, w_ret_pc_re;
    associativity_t replace_line, hit_line, pc_hit_line, pcp4_hit_line, call_hit_line, ret_hit_line;
    logic pc_hit, pcp4_hit, call_hit, ret_hit;

    // for predict

    always_comb begin
        pc_hit = 1'b0;
        pc_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (jrra_pc_pre[i].valid && (jrra_pc_pre[i].tag == get_tag(pc_f1))) begin
                pc_hit  = 1'b1;
                pc_hit_line = associativity_t'(i);
            end
        end 
    end

    always_comb begin
        pcp4_hit = 1'b0;
        pcp4_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (jrra_pc_pre[i].valid && (jrra_pc_pre[i].tag == get_tag(pc_f1+4))) begin
                pcp4_hit = 1'b1;
                pcp4_hit_line = associativity_t'(i);
            end
        end 
    end

    assign hit_pc = pc_hit;
    assign hit_pcp4 = pcp4_hit;
    assign hit = pcp4_hit | pc_hit;
    always_comb begin
        hit_line = '0;
        if(pc_hit) hit_line = pc_hit_line;
        else if(pcp4_hit) hit_line = pcp4_hit_line;
    end

    assign pre_pc = {ret_pc_pre[hit_line].pchi, ret_pc_pre[hit_line].tag, 2'b0};

    // for repalce

    // call update

    always_comb begin
        call_hit = 1'b0;
        call_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_call_pc_re[i].valid && r_call_pc_re[i].tag == get_tag(call_pc)) begin
                call_hit = 1'b1;
                call_hit_line = associativity_t'(i);
            end
        end 
    end

    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r, plru_new;

    assign plru_r = plru_ram[get_index(pc_f1)];

    assign replace_line[0] = plru_r[0];
    assign plru_new[0] = ~hit_line[0];

    always_ff @(posedge clk) begin
        if (hit) begin
            plru_ram[get_index(pc_f1)] <= plru_new;
        end
    end

    always_comb begin
        w_call_pc_re = r_call_pc_re;
        if(~call_hit) begin
            w_call_pc_re[replace_line].pchi = get_pchi(call_pc);
            w_call_pc_re[replace_line].tag = get_tag(call_pc);
            w_call_pc_re[replace_line].valid = '1;
        end
    end

    always_comb begin
        w_ret_pc_re = r_ret_pc_re;
        if(call_hit) begin
            w_ret_pc_re[call_hit_line].pchi = get_pchi(ret_pc);
            w_ret_pc_re[call_hit_line].tag = get_tag(ret_pc);
            w_ret_pc_re[call_hit_line].valid = '1;
        end else begin
            w_ret_pc_re[replace_line].pchi = get_pchi(ret_pc);
            w_ret_pc_re[replace_line].tag = get_tag(ret_pc);
            w_ret_pc_re[replace_line].valid = '1;
        end
    end

    // ret update

    always_comb begin
        ret_hit = 1'b0;
        ret_hit_line = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (r_ret_pc_re[i].valid && r_ret_pc_re[i].tag == get_tag(ret_pc)) begin
                ret_hit = 1'b1;
                ret_hit_line = associativity_t'(i);
            end
        end 
    end

    always_comb begin
        w_jrra_pc_re = r_jrra_pc_re;
        if(ret_hit) begin
            w_jrra_pc_re[ret_hit_line].pchi = get_pchi(jrra_pc);
            w_jrra_pc_re[ret_hit_line].tag = get_tag(jrra_pc);
            w_jrra_pc_re[ret_hit_line].valid = '1;
        end
    end

    // always_comb begin : w_meta_block
    //     for (int i = 0; i < ASSOCIATIVITY; i++) begin
    //         if (~in_rpct && is_write && associativity_t'(i) == replace_line) begin
    //             w_meta[i].valid = 1'b1;
    //             w_meta[i].tag = get_tag(jrra_pc);
    //         end else begin
    //             w_meta[i] = r_meta_in_rpct[i];
    //         end
    //     end 
    // end

    index_t reset_addr, index_ret_pc, index_call_pc, index_f1_pc;
    pchi_t pchi_jrra, pchi_ret, pchi_call;

    // assign pchi_jrra = get_pchi(jrra_pc);
    // assign pchi_ret = get_pchi(ret_pc);
    // assign pchi_call = get_pchi(call_pc);

    // assign index_ret_pc = get_index(ret_pc);
    // assign index_call_pc = get_index(call_pc);
    // assign index_f1_pc = get_index(pc_f1);

    always_ff @( posedge clk ) begin : reset
            reset_addr <= reset_addr+1;
    end

    RAM_SinglePort #(
		.ADDR_WIDTH(INDEX_BITS),
		.DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
		.BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
		.READ_LATENCY(0)
    ) call_pc_ram (
        .clk(clk), .en(is_call | ~resetn),
        .addr(resetn ? get_index(call_pc) : reset_addr),
        .strobe(1'b1),
        .wdata(resetn ? w_call_pc_re : '0),
        .rdata(r_call_pc_re)
    );


    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) ret_pc_ram(
        .clk(clk),

        .en_1(is_call | ~resetn), //port1 for replace
        .addr_1(resetn ? get_index(call_pc) : reset_addr),
        .rdata_1(r_ret_pc_re),
        .strobe('1),  
        .wdata(resetn ? w_ret_pc_re : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(pc_f1)),
        .rdata_2(ret_pc_pre)
    );

    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .BYTE_WIDTH($bits(meta_t) * ASSOCIATIVITY),
        .READ_LATENCY(0)
    ) jrra_pc_ram(
        .clk(clk),

        .en_1(is_ret | ~resetn), //port1 for replace
        .addr_1(resetn ? get_index(ret_pc) : reset_addr),
        .rdata_1(r_jrra_pc_re),
        .strobe('1),  
        .wdata(resetn ? w_jrra_pc_re : '0),

        .en_2(1'b1), //port2 for predict
        .addr_2(get_index(pc_f1)),
        .rdata_2(jrra_pc_pre)
    );

endmodule


`endif 