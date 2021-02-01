`include "refcpu/defs.svh"

module AddrCheck (
    input  context_t ctx,
    output context_t out
);
    `FORMAT_ITYPE(opcode, base, _unused_rt, offset, ctx.instr);

    addr_t addr;
    assign addr = ctx.r[base] + `SIGN_EXTEND(offset, 32);

    always_comb begin
        out = ctx;
        out.args.mem.addr = addr;

        unique case (opcode)
        OP_SW: begin
            if (|addr[1:0]) begin
                out.state = S_EXCEPTION;
                out.args.exception.code = EX_ADES;
            end else begin
                out.state = S_STORE;
                out.args.mem.size = MSIZE4;
            end
        end

        OP_LW: begin
            if (|addr[1:0]) begin
                out.state = S_EXCEPTION;
                out.args.exception.code = EX_ADEL;
            end else begin
                out.state = S_LOAD;
                out.args.mem.size = MSIZE4;
            end
        end

        default:
            // Decode should guarantee that no other instruction
            // enters this state.
            out.state = S_UNKNOWN;
        endcase
    end
endmodule
