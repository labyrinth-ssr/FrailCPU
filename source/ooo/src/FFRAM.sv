module FFRAM #(
    parameter int WIDTH   = 32,
    parameter int DEPTH   = 32,
    parameter int N_WRITE = 1,
    parameter int N_READ  = 1,

    localparam int ADDR_WIDTH = $clog2(DEPTH),

    localparam type word_t = logic [WIDTH-1:0],
    localparam type addr_t = logic [ADDR_WIDTH-1:0]
) (
    input logic clk, resetn,

    input logic  [N_WRITE-1:0] wen,
    input addr_t [N_WRITE-1:0] waddr,
    input word_t [N_WRITE-1:0] wdata,

    input  addr_t [N_READ-1:0] raddr,
    output word_t [N_READ-1:0] rdata
);
    word_t [DEPTH-1:0] prev, next;

    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            prev[i] = '0;
        end
    end

    always_comb begin
        next = prev;

        for (int i = 0; i < N_WRITE; i++)
        if (wen[i]) begin
            for (int j = 0; j < DEPTH; j++) begin
                if (waddr[i] == addr_t'(j))
                    next[j] = wdata[i];
            end
        end
    end

    always_ff @(posedge clk)
    if (resetn) begin
        prev <= next;

        for (int i = 0; i < N_READ; i++) begin
            rdata[i] <= next[raddr[i]];
        end
    end else begin
        for (int i = 0; i < N_READ; i++) begin
            rdata[i] <= '0;
        end
    end
endmodule
