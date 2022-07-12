`include "common.svh"

module DCache (
    input logic clk, resetn,

    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
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

    localparam DATA_BITS = $clog2(BYTES_PER_DATA);
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

    localparam type cbus_state_t = enum logic[1:0] {
        IDLE, FETCH, WRITEBACK
    };

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

    addr_t dreq_addr;
    assign dreq_addr = dreq.addr;

    //meta_ram, plru_ram
    typedef struct packed {
        u1 valid;
        u1 dirty;
        tag_t tag;
    } info_t;

    localparam type meta_t = info_t [ASSOCIATIVITY-1:0];

    index_t meta_addr;
    meta_t meta_r, meta_w;
    assign meta_addr = dreq_index;

    index_t plru_addr;
    plru_t plru_r, plru_w;
    assign plru_addr = dreq_index;
    
    RAM_SinglePort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(meta_t)),
        .BYTE_WIDTH($bits(meta_t)),
        .MEM_TYPE(0),
        .READ_LATENCY(0)
    ) meta_ram(
        .clk(clk), 
        .en(1),
        .addr(meta_addr),
        .strobe(1),
        .wdata(meta_w),
        .rdata(meta_r)
    );

    RAM_SinglePort #(
        .ADDR_WIDTH(INDEX_BITS),
        .DATA_WIDTH($bits(plru_t)),
        .BYTE_WIDTH($bits(plru_t)),
        .MEM_TYPE(0),
        .READ_LATENCY(0)
    ) plru_ram(
        .clk(clk), 
        .en(1),
        .addr(plru_addr),
        .strobe(1),
        .wdata(plru_w),
        .rdata(plru_r)
    );

    //计算hit
    logic hit;
    logic buffer_hit, cache_hit;
    assign hit = buffer_hit | cache_hit;
    associativity_t hit_line;
    always_comb begin
        cache_hit = '0;
        hit_line= '0;
        for (int i = 0; i < ASSOCIATIVITY; i++) begin
            if (meta_r[i].valid && meta_r[i].tag == dreq_tag) begin
                cache_hit = 1'b1;
                hit_line = associativity_t'(i);
                break;
            end
        end 
    end

    //plru_r -> replace_line
    //hit_line + plru_r -> plru_new
    associativity_t replace_line;
    plru_t plru_new;
    PLRU plru(
        .plru_old(plru_r),
        .hit_line,
        .plru_new,
        .replace_line
    );

    //Port 1 
    data_addr_t data_addr;
    word_t data_w, data_r;
    assign data_addr = {hit_line, dreq_index, dreq_offset};
    assign data_w = dreq.data;

    logic data_ok_reg;

    //Port 2
    strobe_t miss_write_en;
    data_addr_t miss_data_addr;
    word_t data_to_buffer;
    assign miss_write_en = (state == FETCH && dcresp.ready) ? {BYTE_PER_DATA{1'b1}} : '0;

    //cbus_state
    cbus_state_t state;

    //cbus
    addr_t cbus_addr;

    //Write_buffer
    buffer_t write_buffer;
    logic buffer_wen;
    offset_t buffer_offset;
    info_t replace_info;
    index_t replace_index;
    record_t buffer_finish;

    assign buffer_hit = replace_info.valid & replace_info.tag == dreq_tag & replace_index == dreq_index;

    //fetch finish
    record_t fetch_finish;

    logic replace_dirty;
    assign replace_dirty = replace_info.valid & replace_info.dirty;

    //hit && miss
    logic hit_avail, miss_avail;
    logic true_hit, true_miss;
    logic dreq_hit, dreq_miss;

    assign hit_avail = state == IDLE 
                    | fetch_finish[dreq_addr.offset]
                    | dreq_addr.tag != cbus_addr.tag
                    | dreq_addr.index != cbus_addr.index
                    | replace_line != miss_data_addr.line;
    assign miss_avail = state == IDLE
                    | (state == FETCH & dcresp.last & ~replace_dirty)
                    | (state == WRITEBACK & dcresp.last);
    assign true_hit = hit & hit_avail;
    assign true_miss = ~hit & miss_avail;
    assign dreq_hit = dreq.valid & true_hit;
    assign dreq_miss = dreq.valid & true_miss;


    //更新meta_ram, plru_ram
    always_comb begin
        meta_w = meta_r;
        plru_w = plru_r;

        if (dreq_hit) begin
            if (|dreq.strobe) begin
                meta_w[hit_line].dirty = 1'b1;
            end

            plru_w = cache_hit ? plru_new : plru_r;
        end
        else if (dreq_miss) begin
            meta_w[replace_line].valid = 1'b1;
            meta_w[replace_line].dirty = 1'b0;
            meta_w[replace_line].tag = dreq_tag;
        end
        else begin
        end

    end

    always_ff(posedge clk) begin
        if (resetn) begin
            if (dreq_miss) begin
                state <= FETCH;
                cbus_addr <= dreq_addr;
                miss_data_addr <= {replace_line, dreq_index, dreq_offset};
                replace_info <= meta_r[replace_line];
                replace_index <= dreq_index;
                fetch_finish <= '0;
                buffer_finish <= '0;
            end

            unique case(state) begin
                FETCH : begin
                    if (dcresp.ready) begin
                        miss_data_addr.offset <= miss_data_addr.offset + 1;
                        fetch_finish[miss_data_addr.offset] <= 1'b1;
                    end
                    buffer_wen <= dcresp.ready;
                    buffer_offset <= miss_data_addr.offset;

                    if (dcresp.last) begin
                        state <= replace_dirty ? WRITEBACK : IDLE;
                        cbus_addr.tag <= replace_info.tag;
                    end
                end

                WRITEBACK : begin
                    if (dcresp.ready) begin
                        state  <= cresp.last ? IDLE : WRITEBACK;
                        miss_data_addr.offset <= miss_data_addr.offset + 1;
                    end
                    buffer_wen <= 0;
                end

                default : begin
                end
            end

            if (buffer_wen) begin
                write_buffer[buffer_offset] <= data_to_buffer;
                buffer_finish[buffer_offset] <= '0;
            end
        end
        else begin
            state <= IDLE;
            buffer_wen <= 0;
            fetch_finish <= '0;
            {buffer_finish, replace_info, replace_index} <= '0;
        end
    end

    always_ff(posedge clk) begin
        if (resetn) begin
            data_ok_reg <= dreq_hit;
        end
        else begin
            data_ok_reg <= '0;
        end
    end


    BRAM #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(DATA_ADDR_BITS),
        .WRITE_MODE("read_first"),
    ) (
        .clk, 
        .resetn,

        // port 1 : dbus
        .en_1(dreq_hit),
        .write_en_1(dreq.strobe),
        .addr_1(data_addr),
        .data_in_1(data_w),
        .data_out_1(data_r),

        // port 2 : cbus && write_buffer
        .en_2(1),
        .write_en_2(miss_write_en),
        .addr_2(miss_data_addr),
        .data_in_2(dcresp.data),
        .data_out_2(data_to_buffer)
    );


    //DBus
    assign dresp.addr_ok = true_hit;
    assign dresp.data_ok = data_ok_reg;
    assign dresp.data = data_r;

    //CBus
    assign dcreq.valid = state != IDLE;     
    assign dcreq.is_write = state == WRITEBACK;  
    assign dcreq.size = MSIZE4;      
    assign dcreq.addr = cbus_addr;      
    assign dcreq.strobe = {BYTE_PER_DATA{1'b1}};   
    assign dcreq.data = write_buffer[miss_data_addr.offset];      
    assign dcreq.len = MLEN16;  

    `UNUSED_OK({clk, resetn, dreq, dcresp});
endmodule
