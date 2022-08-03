`ifndef __ICACHE_SV
`define __ICACHE_SV

`include "common.svh"
`ifdef VERILATOR

`include "../plru.sv"
`endif 
module ICache (
    input logic clk, resetn,

    input  ibus_req_t  ireq_1,
    input  ibus_req_t  ireq_2,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);

    //16KB 2路组相联 1行16个data
    //1 + 7 + 4 + 2
    localparam DATA_PER_LINE = 16;
    localparam ASSOCIATIVITY = 2;
    localparam SET_NUM = 128;

    localparam BYTE_WIDTH = 8;
    localparam BYTE_PER_DATA = 4;
    localparam DATA_WIDTH = BYTE_WIDTH * BYTE_PER_DATA;

    localparam DATA_BITS = $clog2(BYTE_PER_DATA);
    localparam OFFSET_BITS = $clog2(DATA_PER_LINE);
    localparam ASSOCIATIVITY_BITS = $clog2(ASSOCIATIVITY);
    localparam INDEX_BITS = $clog2(SET_NUM);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS - DATA_BITS; 

    localparam DATA_ADDR_BITS = ASSOCIATIVITY_BITS + INDEX_BITS + OFFSET_BITS;

    localparam type align_t = logic [DATA_BITS-1:0];
    localparam type offset_t = logic [OFFSET_BITS-1:0];
    localparam type associativity_t = logic [ASSOCIATIVITY_BITS-1:0];
    localparam type index_t = logic [INDEX_BITS-1:0];
    localparam type tag_t = logic [TAG_BITS-1:0];

    localparam type data_addr_t = struct packed {
        associativity_t line;
        index_t index;
        offset_t offset;
    };
    localparam type addr_t = struct packed {
        tag_t tag;
        index_t index;
        offset_t offset;
        align_t align;
    };
    localparam type buffer_t = word_t [DATA_PER_LINE-1:0];
    localparam type record_t = logic [DATA_PER_LINE-1:0];

    localparam type plru_t = logic [ASSOCIATIVITY-2:0];

    localparam type state_t = enum logic[2:0] {
        IDLE, FETCH_1, FETCH_2
    };

    addr_t ireq_1_addr, ireq_2_addr;
    assign ireq_1_addr = ireq_1.addr;
    assign ireq_2_addr = ireq_2.addr;

    index_t reset_counter;
    always_ff @(posedge clk) begin
        reset_counter <= reset_counter + 1;
    end

     //state
    state_t state;

    //meta_ram
    typedef struct packed {
        logic valid;
        tag_t tag;
    } info_t;

    localparam type meta_t = info_t [ASSOCIATIVITY-1:0];

    index_t meta_addr_1, meta_addr_2;
    meta_t meta_r_1, meta_r_2;
    meta_t meta_w;
    logic meta_en;

    assign meta_addr_1 = resetn ? ((state==FETCH_2) ? ireq_2_addr.index
                                                    : ireq_1_addr.index)
                                : reset_counter[INDEX_BITS-1:0];

    assign meta_addr_2 = ireq_2_addr.index;
    assign meta_en = (~resetn|state==FETCH_1|state==FETCH_2) ? 1'b1 : 0;
    
    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t)),
        .BYTE_WIDTH($bits(meta_t)),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk), 
        .en_1(1'b1), 
        .en_2(1'b1),
        .addr_1(meta_addr_1), 
        .addr_2(meta_addr_2),
        .strobe(meta_en),  
        .wdata(meta_w), 
        .rdata_1(meta_r_1), 
        .rdata_2(meta_r_2)
    );

    //计算hit
    logic hit_1, hit_2;
    logic [ASSOCIATIVITY-1:0] hit_1_bits, hit_2_bits;
    associativity_t hit_line_1, hit_line_2;

    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_1_bits[i] = meta_r_1[i].valid && meta_r_1[i].tag == ireq_1_addr.tag;
    end
    assign hit_1 = |hit_1_bits;
    always_comb begin
        hit_line_1 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_1 |= hit_1_bits[i] ? associativity_t'(i) : 0;
        end
    end

    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_2_bits[i] = meta_r_2[i].valid && meta_r_2[i].tag == ireq_2_addr.tag;
    end
    assign hit_2 = |hit_2_bits;
    always_comb begin
        hit_line_2 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_2 |= hit_2_bits[i] ? associativity_t'(i) : 0;
        end
    end
    
    //hit && miss
    logic ireq_hit_1, ireq_hit_2;
    logic ireq_avail;
    logic ireq_hit;
    
    assign ireq_avail = state == IDLE;
    assign ireq_hit_1 = ireq_1.valid & ireq_avail & hit_1;
    assign ireq_hit_2 = ireq_2.valid & ireq_avail & hit_2;
    assign ireq_hit = (ireq_hit_1 & ireq_hit_2) | (ireq_hit_1 & ~ireq_2.valid);

    data_addr_t miss_addr;
    addr_t cbus_addr;
    
    //plru
    plru_t [SET_NUM-1 : 0] plru, plru_new;
    associativity_t replace_line_1, replace_line_2;

    assign replace_line_1 = plru[ireq_1_addr.index];
    assign replace_line_2 = (ireq_1_addr.index == ireq_2_addr.index) ? ~hit_line_1
                                                               : plru[ireq_2_addr.index];


    always_comb begin
        plru_new = plru;
        for (int i = 0; i < SET_NUM; i++) begin
            if (ireq_hit_1) begin
                plru_new[i] = (ireq_1_addr.index == index_t'(i)) ? ~hit_line_1 : plru[i];
            end  
            if (ireq_hit_2) begin      
                plru_new[i] = (ireq_2_addr.index == index_t'(i)) ? ~hit_line_2 : plru[i];    
            end   
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            plru <= plru_new;
        end
        else begin
            plru <= '0;
        end
    end

    //Port 1 : ireq_1 
    logic port_1_en;
    strobe_t port_1_wen;
    data_addr_t port_1_addr;
    word_t port_1_data_w, port_1_data_r;

    assign port_1_en = ireq_hit;       
    assign port_1_wen = '0;                    
    assign port_1_addr = {hit_line_1, ireq_1_addr.index, ireq_1_addr.offset};                   
    assign port_1_data_w = '0;
                                  

    //Port 2 : ireq_2 & cbus
    logic port_2_en;
    strobe_t port_2_wen;
    data_addr_t port_2_addr;
    word_t port_2_data_w, port_2_data_r;

    assign port_2_en = (state==IDLE) ? ireq_hit : 1'b1;
    assign port_2_wen = (state==FETCH_1|state==FETCH_2) ? {BYTE_PER_DATA{1'b1}}
                                                        : '0;
    assign port_2_addr = (state==IDLE) ? {hit_line_2, ireq_2_addr.index, ireq_2_addr.offset} : miss_addr;
    assign port_2_data_w = (state==FETCH_1|state==FETCH_2) ? icresp.data : '0;
            

    logic data_ok_reg;
    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= ireq_hit;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case (state)
                IDLE: begin
                    if (ireq_1.valid & ~hit_1) begin
                        state <= FETCH_1;
                        
                        miss_addr <= {replace_line_1, ireq_1_addr.index, ireq_1_addr.offset};
                    end

                    else if (hit_1 & ireq_2.valid & ~hit_2) begin
                        state <= FETCH_2;
                        
                        miss_addr <= {replace_line_2, ireq_2_addr.index, ireq_2_addr.offset};
                    end

                    else begin
                    end
                end

                FETCH_1: begin
                    if (icresp.ready) begin
                        state  <= icresp.last ? IDLE : FETCH_1; 
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                FETCH_2: begin
                    if (icresp.ready) begin
                        state  <= icresp.last ? IDLE : FETCH_2;
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                default: begin   
                end
            endcase  
        end
        else begin
            state <= IDLE;
            miss_addr <= '0;
        end
    end

    always_comb begin
        cbus_addr = '0;
        unique case (state)
            FETCH_1: begin
                cbus_addr = ireq_1_addr;
            end

            FETCH_2: begin
                cbus_addr = ireq_2_addr;
            end

            default: begin   
            end
        endcase
    end

    always_comb begin
        meta_w = meta_r_1;
        if (resetn) begin
            unique case (state)
                FETCH_1: begin
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (replace_line_1 == associativity_t'(i)) begin
                            meta_w[i].tag = ireq_1_addr.tag;
                            meta_w[i].valid = 1'b1;
                        end
                        else begin
                        end
                    end
                    
                end

                FETCH_2: begin
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (replace_line_2 == associativity_t'(i)) begin
                            meta_w[i].tag = ireq_2_addr.tag;
                            meta_w[i].valid = 1'b1;
                        end
                        else begin
                        end
                    end
                end
                
                default: begin   
                end
            endcase    
        end
        else begin
            meta_w = '0;
        end
        
    end

    RAM_TrueDualPort #(
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .DATA_WIDTH(DATA_WIDTH),
        .BYTE_WIDTH(BYTE_WIDTH),
        .MEM_TYPE(0),
	    .READ_LATENCY(1)
    ) data_ram(
        .clk, 

        .en_1(port_1_en), 
        .addr_1(port_1_addr), 
        .strobe_1(port_1_wen), 
        .wdata_1(port_1_data_w), 
        .rdata_1(port_1_data_r),

        .en_2(port_2_en),
        .addr_2(port_2_addr),
        .strobe_2(port_2_wen),
        .wdata_2(port_2_data_w),
        .rdata_2(port_2_data_r)
    );


    //ibus
    assign iresp.addr_ok = ireq_hit;
    assign iresp.data_ok = data_ok_reg;
    assign iresp.data = {port_2_data_r, port_1_data_r};

    //CBus
    assign icreq.valid = state != IDLE;     
    assign icreq.is_write = 0;  
    assign icreq.size = MSIZE4;      
    assign icreq.addr = cbus_addr;      
    assign icreq.strobe = 0;   
    assign icreq.data = 0;      
    assign icreq.len = MLEN16;  

endmodule

`endif
