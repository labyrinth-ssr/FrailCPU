`include "pipes.svh"

module pcreg
 (
    input clk,
    input reset,
    input pcselect_data_t dataP_nxt,
    output pcselect_data_t dataP,
    input stallF,
    input forward_pc_type_t forward_pc_type,
    input u1 i_cache
);
always_ff @( posedge clk ) begin
		if (reset) begin
			dataP.pc<=32'hbfc0_0000;//
            dataP.cache_i<='0;
		end else if(~stallF) begin
			dataP.pc<=dataP_nxt.pc;
            dataP.cache_i<=dataP_nxt.cache_i;
		end
	end

    always_ff @(posedge clk) begin
        if (reset) begin
            {dataP.forward_pc,dataP.forward_pc_valid,dataP.forward_pc_type,dataP.forward_cachei}<='0;
        end else if (stallF&(|forward_pc_type)) begin
            {dataP.forward_pc,dataP.forward_pc_valid,dataP.forward_pc_type,dataP.forward_cachei}<={dataP_nxt.forward_pc,dataP_nxt.forward_pc_valid,dataP_nxt.forward_pc_type,dataP_nxt.forward_cachei};
        end else if (~stallF) begin
            {dataP.forward_pc,dataP.forward_pc_valid,dataP.forward_pc_type,dataP.forward_cachei}<='0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            {dataP.refetch_pc,dataP.refetch_pc_valid}<='0;
        end else if (dataE[1].ctl.cache_i) begin
            {dataP.refetch_pc,dataP.refetch_pc_valid}<={dataP_nxt.refetch_pc,dataP_nxt.refetch_pc_valid};
        end else if (~stallF&~dataP.forward_cachei) begin
            {dataP.refetch_pc,dataP.refetch_pc_valid}<='0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dataP.pc_valid<='1;
        end else if (reset|(stallF&(|forward_pc_type))) begin
            dataP.pc_valid<='0;
        end else if (~stallF) begin
            dataP.pc_valid<='1;
        end
    end

endmodule
