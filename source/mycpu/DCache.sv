`include "common.svh"
`include "PLRU.sv"

module DCache (
    input logic clk, resetn,

    input  dbus_req_t  dreq_1,
    output dbus_resp_t dresp_1,
    input  dbus_req_t  dreq_2,
    // output dbus_resp_t dresp_2,
    output cbus_req_t  dcreq,
    input  cbus_resp_t dcresp
);
    //32KB 8路组相联 1行16个data
    //3 + 6 + 4 + 2
    localparam DATA_PER_LINE = 16;
    localparam ASSOCIATIVITY = 8;
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
    localparam type buffer_t = word_t [DATA_PER_LINE-1:0];
    localparam type record_t = logic [DATA_PER_LINE-1:0];

    localparam type plru_t = logic [ASSOCIATIVITY-2:0];

    localparam type state_t = enum logic[2:0] {
        IDLE, FETCH_1, WRITEBACK_1, FETCH_2, WRITEBACK_2
    };

/*
    function offset_t get_offset(addr_t addr);
        return addr[DATA_BITS+OFFSET_BITS-1:DATA_BITS];
    endfunction

    function index_t get_index(addr_t addr);
        return addr[DATA_BITS+INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS+DATA_BITS];
    endfunction

    function tag_t get_tag(addr_t addr);
        return addr[DATA_BITS+INDEX_BITS+OFFSET_BITS+TAG_BITS-1:DATA_BITS+INDEX_BITS+OFFSET_BITS];
    endfunction

    offset_t dreq_offset;
    tag_t dreq_tag;
    index_t dreq_index;

    assign dreq_offset = get_offset(dreq.addr);
    assign dreq_tag = get_tag(dreq.addr);
    assign dreq_index = get_index(dreq.addr);
*/
    dbus_resp_t dresp_2;

    addr_t dreq_1_addr, dreq_2_addr;
    assign dreq_1_addr = dreq_1.addr;
    assign dreq_2_addr = dreq_2.addr;

     //state
    state_t state;

    //buffer
    buffer_t buffer;
    offset_t buffer_offset;
    offset_t offset_count;

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

    assign meta_addr_1 = (state==FETCH_2) ? dreq_2_addr.index
                                          : dreq_1_addr.index;

    assign meta_addr_2 = dreq_2_addr.index;
    assign meta_en = (state==FETCH_1|state==FETCH_2) ? 1'b1 : 0;
    
    LUTRAM_DualPort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t)),
        .BYTE_WIDTH($bits(meta_t)),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk), 
        .en_1(meta_en), 
        .en_2(0),
        .addr_1(meta_addr_1), 
        .addr_2(meta_addr_2),
        .strobe(1),  
        .wdata(meta_w), 
        .rdata_1(meta_r_1), 
        .rdata_2(meta_r_2)
    );

    //dirty_ram
    logic dirty_ram [ASSOCIATIVITY*SET_NUM-1:0];

    //计算hit
    logic hit_1, hit_2;
    associativity_t hit_line_1, hit_line_2;
    always_comb begin
        {hit_1, hit_2} = '0;
        {hit_line_1, hit_line_2} = '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (meta_r_1[i].valid && meta_r_1[i].tag == dreq_1_addr.tag) begin
                hit_1 = 1'b1;
                hit_line_1 = associativity_t'(i);
            end
            if (meta_r_2[i].valid && meta_r_2[i].tag == dreq_2_addr.tag) begin
                hit_2 = 1'b1;
                hit_line_2 = associativity_t'(i);
            end
        end 
    end

    //hit && miss
    logic dreq_hit_1, dreq_hit_2;
    logic dreq_miss_1, dreq_miss_2;
    logic dreq_avail;
    logic dreq_hit;
    
    assign dreq_avail = state == IDLE;
    assign dreq_hit_1 = dreq_1.valid & dreq_avail & hit_1;
    assign dreq_hit_2 = dreq_2.valid & dreq_avail & hit_2;
    assign dreq_hit = (dreq_hit_1 & dreq_hit_2) | (dreq_hit_1 & ~dreq_2.valid);

    data_addr_t miss_addr;
    addr_t cbus_addr;

    //plru_ram
    plru_t plru_ram [SET_NUM-1 : 0];
    plru_t plru_r_1, plru_r_2;
    plru_t plru_w_1, plru_w_2;
    associativity_t replace_line_1, replace_line_2;
    plru_t plru_new_1, plru_new_2;

    assign plru_r_1 = plru_ram[dreq_1_addr.index];
    assign plru_r_2 = (dreq_1_addr.index == dreq_2_addr.index) ? plru_new_1
                                                               : plru_ram[dreq_2_addr.index];

    PLRU plru_1(
        .plru_old(plru_r_1),
        .hit_line(hit_line_1),
        .plru_new(plru_new_1),
        .replace_line(replace_line_1)
    );

    PLRU plru_2(
        .plru_old(plru_r_2),
        .hit_line(hit_line_2),
        .plru_new(plru_new_2),
        .replace_line(replace_line_2)
    );

    //plru_r -> replace_line
    //hit_line + plru_r -> plru_new
    /*
    double miss -> stall forever
    */


    //Port 1 : dreq_1 
    data_addr_t port_1_addr;
    word_t port_1_data_w, port_1_data_r;
    assign port_1_addr = {hit_line_1, dreq_1_addr.index, dreq_1_addr.offset};
    assign port_1_data_w = dreq_1.data;

    //Port 2 : dreq_2 & cbus
    logic port_2_en;
    strobe_t port_2_wen;
    data_addr_t port_2_addr;
    word_t port_2_data_w, port_2_data_r;
    assign port_2_en = (state==IDLE) ? dreq_hit_2 : 1;
    assign port_2_wen = (state==IDLE) ? dreq_2.strobe
                                      : (state==FETCH_1|state==FETCH_2) ? {BYTE_PER_DATA{1'b1}}
                                                                        : '0;
    assign port_2_addr = (state==IDLE) ? {hit_line_2, dreq_2_addr.index, dreq_2_addr.offset}
                                       : miss_addr;
    assign port_2_data_w = (state==IDLE) ? dreq_2.data
                                         : dcresp.data;

    logic data_ok_reg;
    
    logic addr_same;
    assign addr_same = (dreq_1_addr == dreq_2_addr) & (dreq_1.valid & dreq_2.valid);
    //W -> W
    logic w_to_w;
    assign w_to_w = addr_same & |dreq_1.strobe & |dreq_2.strobe;

    //W -> R
    logic w_to_r;
    logic w_to_r_reg;
    word_t w_to_r_data;
    assign w_to_r = addr_same & |dreq_1.strobe & ~|dreq_2.strobe;
    

    logic delay_counter;

    //更新dirty_ram
    always_ff @(posedge clk) begin
        unique case (state)
            IDLE: begin
                if (dreq_hit) begin
                    dirty_ram[{hit_line_1, dreq_1_addr.index}] <= |dreq_1.strobe;
                    if (dreq_2.valid) begin
                        dirty_ram[{hit_line_2, dreq_2_addr.index}] <= |dreq_2.strobe;
                    end
                end
            end

            FETCH_1: begin
                dirty_ram[{replace_line_1, dreq_1_addr.index}] <= '0;
            end
        
            FETCH_2: begin
                dirty_ram[{replace_line_2, dreq_2_addr.index}] <= '0;
            end
            default: begin   
            end
        endcase 
    end

    //hit时更新plru_ram
    always_ff @(posedge clk) begin
        if (dreq_hit) begin
            plru_ram[dreq_1_addr.index] <= (dreq_1_addr.index == dreq_2_addr.index & dreq_2.valid) ? plru_new_2
                                                                                                    : plru_new_1;
            if (dreq_1_addr.index != dreq_2_addr.index & dreq_2.valid) begin
                plru_ram[dreq_2_addr.index] <= plru_new_2;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            unique case (state)
                IDLE: begin
                    if (dreq_1.valid & ~hit_1) begin
                        if (dirty_ram[{replace_line_1, dreq_1_addr.index}] & meta_r_1[replace_line_1].valid) begin
                            state <= WRITEBACK_1;
                        end
                        else begin
                            state <= FETCH_1;
                        end
                        miss_addr <= {replace_line_1, dreq_1_addr.index, dreq_1_addr.offset};
                        offset_count <= dreq_1_addr.offset;
                    end

                    else if (hit_1 & dreq_2.valid & ~hit_2) begin
                        if (dirty_ram[{replace_line_2, dreq_2_addr.index}] & meta_r_2[replace_line_2].valid) begin
                            state <= WRITEBACK_2;
                        end
                        else begin
                            state <= FETCH_2;
                        end
                        miss_addr <= {replace_line_2, dreq_2_addr.index, dreq_2_addr.offset};
                        offset_count <= dreq_2_addr.offset;
                    end

                    else begin
                    end

                    delay_counter <= '0;
                end

                FETCH_1: begin
                    if (cresp.ready) begin
                        state  <= cresp.last ? IDLE : FETCH_1; 
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                WRITEBACK_1: begin
                    if (cresp.ready) begin
                        state  <= cresp.last ? FETCH_1 : WRITEBACK_1;
                        offset_count <= offset_count + 1;
                    end

                    miss_addr.offset <= miss_addr.offset + 1;  
                    buffer_offset <= miss_addr.offset;
                    buffer[buffer_offset] <= port_1_data_r;

                    if (cresp.last) begin
                        miss_addr.offset <= dreq_1_addr.offset;  
                    end

                    delay_counter <= 1'b1;
                end

                FETCH_2: begin
                    if (cresp.ready) begin
                        state  <= cresp.last ? IDLE : FETCH_2;
                        miss_addr.offset <= miss_addr.offset + 1;  
                    end
                end

                WRITEBACK_2: begin
                    if (cresp.ready) begin
                        state  <= cresp.last ? FETCH_2 : WRITEBACK_2;
                        offset_count <= offset_count + 1;
                    end

                    miss_addr.offset <= miss_addr.offset + 1;  
                    buffer_offset <= miss_addr.offset;
                    buffer[buffer_offset] <= port_2_data_r;

                    if (cresp.last) begin
                        miss_addr.offset <= dreq_2_addr.offset;  
                    end

                    delay_counter <= 1'b1;
                end

                default: begin   
                end
            endcase  
        end
        else begin
            state <= IDLE;
        end
    end

    always_comb begin
        cbus_addr = '0;
        unique case (state)
            FETCH_1: begin
                cbus_addr = dreq_1_addr;
            end

            WRITEBACK_1: begin
                cbus_addr = dreq_1_addr;
                cbus_addr.tag = meta_r_1[replace_line_1].tag;
            end

            FETCH_2: begin
                cbus_addr = dreq_2_addr;
            end

            WRITEBACK_2: begin
                cbus_addr = dreq_2_addr;
                cbus_addr.tag = meta_r_2[replace_line_2].tag;
            end

            default: begin   
            end
        endcase
    end

    always_comb begin
        meta_w = meta_r_1;
        unique case (state)
            FETCH_1: begin
                meta_w[replace_line_1].tag = dreq_1_addr.tag;
                meta_w[replace_line_1].valid = 1'b1;
            end

            FETCH_2: begin
                meta_w[replace_line_2].tag = dreq_2_addr.tag;
                meta_w[replace_line_2].valid = 1'b1;
            end

            default: begin   
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= dreq_hit;

            w_to_r_reg <= w_to_r;
            w_to_r_data <= dreq_1.data;
        end
        else begin
            data_ok_reg <= '0;

            w_to_r_reg <= '0;
            w_to_r_data <= '0;
        end
    end


    BRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .WRITE_MODE("read_first")
    ) data_bram(
        .clk, 
        .resetn,

        // port 1
        .en_1(dreq_hit_1 & ~w_to_w),
        .write_en_1(dreq_1.strobe),
        .addr_1(port_1_addr),
        .data_in_1(port_1_data_w),
        .data_out_1(port_1_data_r),

        // port 2
        .en_2(port_2_en),
        .write_en_2(port_2_wen),
        .addr_2(port_2_addr),
        .data_in_2(port_2_data_w),
        .data_out_2(port_2_data_r)
    );


    //DBus
    assign dresp_1.addr_ok = dreq_hit;
    assign dresp_1.data_ok = data_ok_reg;
    assign dresp_1.data = port_1_data_r;

    assign dresp_2.addr_ok = dreq_hit;
    assign dresp_2.data_ok = data_ok_reg;
    assign dresp_2.data = w_to_r_reg ? w_to_r_data : port_2_data_r;

    //CBus
    assign dcreq.valid = state == FETCH_1 | state == FETCH_2 | (state == WRITEBACK_1 & delay_counter) | (state == WRITEBACK_2 & delay_counter);     
    assign dcreq.is_write = state == WRITEBACK_1 | state == WRITEBACK_2;  
    assign dcreq.size = MSIZE4;      
    assign dcreq.addr = cbus_addr;      
    assign dcreq.strobe = {BYTE_PER_DATA{1'b1}};   
    assign dcreq.data = buffer[offset_count];      
    assign dcreq.len = MLEN16;  

    `UNUSED_OK({clk, resetn, dreq_1, dreq_2, dcresp});
endmodule
