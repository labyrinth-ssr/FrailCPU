`ifndef __ICACHE_SV
`define __ICACHE_SV

`include "common.svh"
`include "cache_pkg.svh"
`include "cp0_pkg.svh"
`ifdef VERILATOR

`endif 
module icache (
    input logic clk, resetn,

    input  ibus_req_t  ireq_1,
    input  ibus_req_t  ireq_2,
    output ibus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp,

    input icache_inst_t cache_inst,
    input cp0_taglo_t tag_lo
);
    //16KB 2路组相联 1行16个data
    //1 + 7 + 4 + 2
    localparam DATA_PER_LINE = 16;
    localparam ASSOCIATIVITY = 2;
    localparam SET_NUM = 64;

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

    //meta_ram
    typedef struct packed {
        logic valid;
        tag_t tag;
    } info_t;

    localparam type meta_t = info_t [ASSOCIATIVITY-1:0];

    localparam type plru_t = logic [ASSOCIATIVITY-2:0];

    localparam type state_t = enum logic[3:0] {
        IDLE, FETCH_1, FETCH_2, STORE
    };

    localparam type process_pkg_t = struct packed {
        logic hit_1;
        logic hit_2;
        associativity_t hit_line_1;
        associativity_t hit_line_2;

        logic ireq_en;

        ibus_req_t ireq_1;
        ibus_req_t ireq_2; 
        meta_t meta_r_1;
        meta_t meta_r_2;
        
        cache_oper_t cache_oper;
      
        associativity_t inst_oper_line;
    };

    //for INDEX_INVALID, INDEX_STORE_TAG
    function associativity_t get_line(input addr_t addr);
        return addr[ASSOCIATIVITY_BITS+INDEX_BITS+OFFSET_BITS+DATA_BITS-1:INDEX_BITS+OFFSET_BITS+DATA_BITS];
    endfunction

    function tag_t tag_lo_tag(input addr_t addr);
        return tag_t'(tag_lo[0]);
    endfunction

    function logic tag_lo_valid(input addr_t addr);
        return tag_lo[0];
    endfunction

    function word_t tag_lo_data(input addr_t addr);
        return word_t'(tag_lo[0]);
    endfunction


    //for meta reset
    index_t reset_counter;
    always_ff @(posedge clk) begin
        reset_counter <= reset_counter + 1;
    end

    //stage1
    addr_t ireq_1_addr, ireq_2_addr;

    //process
    addr_t process_ireq_1_addr, process_ireq_2_addr;

    //state
    state_t state;

    //FETCH
    data_addr_t miss_addr;

    //dota_ok 延迟
    logic data_ok_reg;
    
    //meta_ram
    meta_t meta_ram [SET_NUM-1:0];
    logic meta_en;
    index_t meta_w_addr;
    meta_t meta_w;
    index_t meta_r_addr_1, meta_r_addr_2;
    meta_t meta_r_1, meta_r_2;

    //plru
    logic index_equal;
    plru_t [SET_NUM-1 : 0] plru, plru_new;
    associativity_t process_replace_line_1, process_replace_line_2; //process

    //判断hit
    logic hit_1, hit_2;
    logic [ASSOCIATIVITY-1:0] hit_1_bits, hit_2_bits;
    associativity_t hit_line_1, hit_line_2;

    //hit & miss
    logic ireq_en;

    logic en;

    logic process_cache_hit_1, process_cache_hit_2;

    //Port1
    logic port_1_en;
    strobe_t port_1_wen;
    data_addr_t port_1_addr;
    word_t port_1_data_w, port_1_data_r;

    //Port2
    logic port_2_en;
    strobe_t port_2_wen;
    data_addr_t port_2_addr;
    word_t port_2_data_w, port_2_data_r;

    //FETCH结束,下一周期addr_ok
    state_t finish_state;
    logic finish, finish_reg;

    associativity_t replace_line_1_reg, replace_line_2_reg;

    //FSM
    logic fetch_1_end, fetch_2_end, store_end;

    //防止重复FETCH
    logic same_line;

    //for cache_inst invalid
    associativity_t index_line;
    associativity_t inst_oper_line;
    cache_oper_t cache_oper;

    process_pkg_t cache_handle;

    assign index_line = get_line(ireq_1_addr);
    assign inst_oper_line = ((cache_inst==I_INDEX_INVALID|cache_inst==I_INDEX_STORE_TAG)&ireq_1.valid)) ? index_line : hit_line_1;
    assign cache_oper = ((cache_inst==I_INDEX_INVALID|(cache_inst==I_HIT_INVALID&hit_1))&ireq_1.valid) ? INVALID
                        : (cache_inst==I_INDEX_STORE_TAG&ireq_1.valid) ? INDEX_STORE
                        : (cache_inst==I_UNKNOWN) ? REQ
                        : NULL;

    //第一阶段读meta, 第二阶段写meta
    assign ireq_1_addr = ireq_1.addr;
    assign ireq_2_addr = ireq_2.addr;

    assign meta_en = (~resetn|cache_handle.cache_oper==INVALID|state==STORE|state==FETCH_1|state==FETCH_2);
    assign meta_w_addr = resetn ? ((state==FETCH_2) ? process_ireq_2_addr.index
                                                    : process_ireq_1_addr.index)
                                : reset_counter[INDEX_BITS-1:0];
    always_ff @(posedge clk) begin
        if (meta_en) begin
            meta_ram[meta_w_addr] <= meta_w;
        end
    end
    assign meta_r_addr_1 = ireq_1_addr.index;
    assign meta_r_addr_2 = ireq_2_addr.index;
    assign meta_r_1 = meta_ram[meta_r_addr_1];
    assign meta_r_2 = meta_ram[meta_r_addr_2];

    //meta_w
    always_comb begin
        meta_w = '0;
        if (resetn) begin
            unique case (cache_handle.cache_oper)
                INVALID: begin
                    meta_w = cache_handle.meta_r_1;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (cache_handle.inst_oper_line == associativity_t'(i)) begin
                            meta_w[i].valid = 1'b0;
                        end
                        else begin
                        end
                    end
                end

                INDEX_STORE: begin
                    meta_w = cache_handle.meta_r_1;
                    for (int i = 0; i < ASSOCIATIVITY; i++) begin
                        if (cache_handle.inst_oper_line == associativity_t'(i) & en) begin
                            meta_w[i].valid = tag_lo_valid(tag_lo);
                            meta_w[i].tag = tag_lo_tag(tag_lo);
                        end
                        else begin
                        end
                    end
                end

                REQ: begin
                    unique case (state)
                        FETCH_1: begin
                            meta_w = cache_handle.meta_r_1;
                            for (int i = 0; i < ASSOCIATIVITY; i++) begin
                                if (process_replace_line_1 == associativity_t'(i)) begin
                                    meta_w[i].tag = process_ireq_1_addr.tag;
                                    meta_w[i].valid = 1'b1;
                                end
                                else begin
                                end
                            end
                            
                        end
                        FETCH_2: begin
                            meta_w = cache_handle.meta_r_2;
                            for (int i = 0; i < ASSOCIATIVITY; i++) begin
                                if (process_replace_line_2 == associativity_t'(i)) begin
                                    meta_w[i].tag = process_ireq_2_addr.tag;
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

                default: begin
                end
            endcase   
        end
        else begin
        end
    end

    //stage1 计算hit 
    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_1_bits[i] = meta_r_1[i].valid & meta_r_1[i].tag == ireq_1_addr.tag;
    end
    assign hit_1 = |hit_1_bits;
    always_comb begin
        hit_line_1 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_1 |= hit_1_bits[i] ? associativity_t'(i) : 0;
        end
    end

    for (genvar i = 0; i < ASSOCIATIVITY; i++) begin
        assign hit_2_bits[i] = meta_r_2[i].valid & meta_r_2[i].tag == ireq_2_addr.tag;
    end
    assign hit_2 = |hit_2_bits;
    always_comb begin
        hit_line_2 = 0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            hit_line_2 |= hit_2_bits[i] ? associativity_t'(i) : 0;
        end
    end
    
    assign ireq_en = (cache_inst==I_UNKNOWN & (~ireq_1.valid|hit_1) & (~ireq_2.valid|hit_2))
                    | (cache_inst==I_HIT_INVALID)
                    | (cache_inst==I_INDEX_INVALID)
                    | (cache_inst==I_INDEX_STORE_TAG & ~ireq_1.valid);


    always_ff @(posedge clk) begin
        if (resetn) begin
            if (en & ~ireq_en) begin
                en <= '0; 
            end
            else if (~en & finish) begin
                en <= 1'b1;
            end    
        end
        else begin
            en <= 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (en) begin
                cache_handle.hit_1 <= hit_1;
                cache_handle.hit_2 <= hit_2;
                cache_handle.hit_line_1 <= hit_line_1;
                cache_handle.hit_line_2 <= hit_line_2;
                cache_handle.ireq_en <= ireq_en;

                cache_handle.ireq_1 <= ireq_1;
                cache_handle.ireq_2 <= ireq_2;
                cache_handle.meta_r_1 <= meta_r_1;
                cache_handle.meta_r_2 <= meta_r_2;   

                cache_handle.cache_oper <= cache_oper;
                cache_handle.inst_oper_line <= inst_oper_line;
            end
            
        end
        else begin
            cache_handle <= '0;
        end
    end


    //PLRU 
    assign process_ireq_1_addr = cache_handle.ireq_1.addr;
    assign process_ireq_2_addr = cache_handle.ireq_2.addr;
    assign process_cache_hit_1 = cache_handle.hit_1 & cache_handle.ireq_1.valid;
    assign process_cache_hit_2 = cache_handle.hit_2 & cache_handle.ireq_2.valid;

    
    assign index_equal = process_ireq_1_addr.index==process_ireq_2_addr.index;
    assign process_replace_line_1 = (index_equal & cache_handle.hit_2) ? ~cache_handle.hit_line_2 : plru[process_ireq_1_addr.index];
    assign process_replace_line_2 = (index_equal & cache_handle.hit_1) ? ~cache_handle.hit_line_1 : plru[process_ireq_2_addr.index];
                                        
    always_comb begin
        plru_new = plru;
        for (int i = 0; i < SET_NUM; i++) begin         
            if (process_cache_hit_1) begin
                plru_new[i] = process_ireq_1_addr.index == index_t'(i) ? ~cache_handle.hit_line_1 : plru[i];
            end
            else if (state==FETCH_1 & icresp.last) begin
                plru_new[i] = process_ireq_1_addr.index == index_t'(i) ? ~process_replace_line_1 : plru[i];
            end

            if (process_cache_hit_2) begin
                plru_new[i] = process_ireq_2_addr.index == index_t'(i) ? ~cache_handle.hit_line_2 : plru[i];
            end
            else if (state==FETCH_2 & icresp.last) begin
                plru_new[i] = process_ireq_2_addr.index == index_t'(i) ? ~process_replace_line_2 : plru[i];
            end
        end
    end
    always_ff @(posedge clk) begin
        if (resetn) begin
            if (cache_handle.cache_oper==REQ) begin
                plru <= plru_new;
            end
        end
        else begin
            plru <= '0;
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            if (state==FETCH_1 & icresp.last) begin
                replace_line_1_reg <= process_replace_line_1;
            end
            if (state==FETCH_2 & icresp.last) begin
                replace_line_2_reg <= process_replace_line_2;
            end
            else if (same_line & icresp.last) begin
                replace_line_2_reg <= process_replace_line_1;
            end
        end
        else begin
            replace_line_1_reg <= '0;
            replace_line_2_reg <= '0;
        end
    end


    
    assign addr_same = (process_ireq_1_addr[31:2] == process_ireq_2_addr[31:2]) & (cache_handle.ireq_1.valid & cache_handle.ireq_2.valid);
    

    assign finish_state = (cache_handle.ireq_2.valid & ~cache_handle.hit_2 & ~same_line) ? FETCH_2 : FETCH_1;
    assign finish = (cache_handle.cache_oper==REQ&state==finish_state&icresp.last)
                    | (cache_handle.cache_oper==INDEX_STORE&(&miss_addr.offset));
    

    always_ff @(posedge clk) begin
        if (resetn) begin
            finish_reg <= finish;
        end
        else begin
            finish_reg <= '0;
        end
    end


    //Port 1 : ireq_1 
    assign port_1_en = 1'b1;       
    assign port_1_wen = '0;                    
    assign port_1_addr.line = cache_handle.hit_1 ? cache_handle.hit_line_1 : replace_line_1_reg;   
    assign port_1_addr.index = process_ireq_1_addr.index;   
    assign port_1_addr.offset = process_ireq_1_addr.offset;                   
    assign port_1_data_w = '0;
                                  

    //Port 2 : ireq_2 & cbus
    assign port_2_en = 1'b1;
    assign port_2_wen = (state==FETCH_1|state==FETCH_2|state==STORE) ? {BYTE_PER_DATA{1'b1}} : '0;
    assign port_2_addr = (state==IDLE) ? (cache_handle.hit_2 ? {cache_handle.hit_line_2, process_ireq_2_addr.index, process_ireq_2_addr.offset} 
                                                            : {replace_line_2_reg, process_ireq_2_addr.index, process_ireq_2_addr.offset})
                                       : miss_addr;
    assign port_2_data_w = (state==FETCH_1|state==FETCH_2) ? icresp.data 
                            : state==STORE ? tag_lo_data(tag_lo) : '0;




    assign same_line = process_ireq_1_addr[31:OFFSET_BITS+DATA_BITS]==process_ireq_2_addr[31:OFFSET_BITS+DATA_BITS] & cache_handle.ireq_1.valid;


    //FSM
    always_ff @(posedge clk) begin
        if (resetn) begin
            if (~en) begin
                unique case (state)
                    IDLE: begin
                        unique case(cache_handle.cache_oper)
                            INDEX_STORE: begin
                                if (~store_end) begin
                                    state <= STORE;
                                    miss_addr <= {cache_handle.inst_oper_line, process_ireq_1_addr.index, offset_t'(1'b0)};
                                end   
                            end

                            REQ: begin
                                if (cache_handle.ireq_1.valid & ~cache_handle.hit_1 & ~fetch_1_end) begin
                                    state <= FETCH_1;
                                    miss_addr <= {process_replace_line_1, process_ireq_1_addr.index, offset_t'(1'b0)};
                                end
                                else if (cache_handle.ireq_2.valid & ~cache_handle.hit_2 & ~fetch_2_end & ~same_line) begin
                                    state <= FETCH_2;
                                    miss_addr <= {process_replace_line_2, process_ireq_2_addr.index, offset_t'(1'b0)};
                                end
                                else begin
                                end        
                            end

                            default: begin
                            end
                        endcase
                    
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

                    STORE: begin
                        state <= (&miss_addr.offset) ? IDLE : STORE;
                        miss_addr.offset <= miss_addr.offset + 1;
                    end


                    default: begin   
                    end
                endcase  
            end
        end
        else begin
            state <= IDLE;
            miss_addr <= '0;
        end
    end



    always_ff @(posedge clk) begin
        if (resetn) begin
            if (finish_reg) begin
                fetch_1_end <= '0;
                fetch_2_end <= '0;
                store_end <= '0;
            end
            else begin
                fetch_1_end <= state==FETCH_1 ? 1'b1 : fetch_1_end;
                fetch_2_end <= state==FETCH_2 ? 1'b1 : fetch_2_end;
                store_end <= state==STORE ? 1'b1 : store_end;
            end
        end
        else begin
            fetch_1_end <= '0;
            fetch_2_end <= '0;
            store_end <= '0;
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



    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= en;
        end
        else begin
            data_ok_reg <= '0;
        end
    end

    //ibus 
    assign iresp.addr_ok = en;
    assign iresp.data_ok = data_ok_reg;
    assign iresp.data = {port_2_data_r, port_1_data_r};


    //CBus
    assign icreq.valid = state==FETCH_1 | state==FETCH_2;     
    assign icreq.is_write = 0;  
    assign icreq.size = MSIZE4;      
    assign icreq.addr = state==FETCH_1 ? {ireq_1_addr.tag, ireq_1_addr.index, offset_t'(1'b0), align_t'(1'b0)} : {ireq_2_addr.tag, ireq_2_addr.index, offset_t'(1'b0), align_t'(1'b0)};      
    assign icreq.strobe = '0;    
    assign icreq.data = '0;    
    assign icreq.len = MLEN16;  

    `UNUSED_OK({clk, resetn, ireq_1, ireq_2, icresp});
endmodule

`endif