`include "common.svh"

module StupidBuffer (
    input logic clk, resetn,

    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    output cbus_req_t  creq,
    input  cbus_resp_t cresp
);
    // typedefs
    typedef enum i2 {
        IDLE,
        FETCH,
        READY,
        FLUSH
    } state_t;

    typedef union packed {
        word_t data;
        i8 [3:0] lanes;
    } view_t;

    typedef i4 offset_t;

    // registers
    state_t    state;
    dbus_req_t req;
    offset_t   offset;
    view_t [15:0] buffer;

    // wires
    view_t   wdata;
    offset_t start;

    assign wdata = req.data;
    assign start = req.addr[5:2];

    // DBus driver
    assign dresp.addr_ok = state == IDLE;
    assign dresp.data_ok = state == READY;
    assign dresp.data    = buffer[start];

    // CBus driver
    assign creq.valid    = state == FETCH || state == FLUSH;
    assign creq.is_write = state == FLUSH;
    assign creq.size     = MSIZE4;
    assign creq.addr     = req.addr;
    assign creq.strobe   = 4'b1111;
    assign creq.data     = buffer[offset];
    assign creq.len      = MLEN16;

    // the FSM
    always_ff @(posedge clk)
    if (resetn) begin
        unique case (state)
        IDLE: if (dreq.valid) begin
            state  <= FETCH;
            req    <= dreq;
            offset <= dreq.addr[5:2];
        end

        FETCH: if (cresp.ready) begin
            state  <= cresp.last ? READY : FETCH;
            offset <= offset + 1;

            // buffer[offset] <= cresp.data;
            for (int i = 0; i < 16; i++) begin
                if (offset_t'(i) == offset)
                    buffer[i] <= cresp.data;
            end
        end

        READY: begin
            state  <= (|req.strobe) ? FLUSH : IDLE;
            offset <= start;  // not required

            // if (strobe[j]) buffer[start][j] <= wdata[j];
            for (int i = 0; i < 16; i++)
            for (int j = 0; j < 4; j++) begin
                if (offset_t'(i) == start && req.strobe[j])
                    buffer[i].lanes[j] <= wdata.lanes[j];
            end
        end

        FLUSH: if (cresp.ready) begin
            state  <= cresp.last ? IDLE : FLUSH;
            offset <= offset + 1;
        end

        endcase
    end else begin
        state <= IDLE;

        {req, offset, buffer} <= '0;
    end

    // for Verilator
    logic _unused_ok = &{req.valid, req.size};
endmodule
