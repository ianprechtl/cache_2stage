`ifndef _TAG_LOOKUP_TABLE_FA_V_
`define _TAG_LOOKUP_TABLE_FA_V_

module tag_lookup_table_fa #(
	// port parameters
	parameter BW_ACCESS_ADDR 		= 0, 	
 	parameter N_WORDS_PER_BLOCK 	= 0, 
 	// design parameters
 	parameter N_CAPACITY_BLOCKS 	= 0
 	// derived parameters
	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS)
	`endif
)(
	input 							clock_i, 				// write edge
	input 							resetn_i, 				// reset active low 		
	input 							wren_i, 				// write enable (write new entry)
	input 							rmen_i, 				// remove enable (invalidate entry) 
	input [BW_ACCESS_ADDR-1:0] 		access_addr_search_i, 	// access_addr -> cache_addr
	output[BW_ACCESS_ADDR-1:0] 		access_addr_search_o, 	// access_addr -> cache_addr 
	input [BW_ACCESS_ADDR-1:0] 		access_addr_write_i, 	// access_addr to write
	input [BW_CAPACITY_BLOCKS-1:0] 	cache_addr_i, 			// cache_addr -> access_addr & where to write access_addr to
	output[BW_CAPACITY_BLOCKS-1:0] 	cache_addr_search_o, 	// tag to write to tag memory
	output 							hit_o 					
);

// parameterizations
// -----------------------------------------------------------------------------------------------
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(N_WORDS_PER_BLOCK);
localparam BW_ACCESS_TAG 		= BW_ACCESS_ADDR - BW_WORDS_PER_BLOCK;
`ifndef SIMULATION_SYNTHESIS
localparam BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS);
`endif

// access_addr <-> cache_addr translations
// -----------------------------------------------------------------------------------------------
reg 	[BW_ACCESS_TAG-1:0]		tag_mem 		[0:N_CAPACITY_BLOCKS-1];	 	// where block tags are stored
wire 	[N_CAPACITY_BLOCKS-1:0]	matchbits;										// high if there is a match
reg		[N_CAPACITY_BLOCKS-1:0]	validbits_reg;									// high if tag has been written into tag memory
 
// access-> cache comparator array
wire 	[BW_ACCESS_TAG-1:0] 	tag_search_bus,
								tag_write_bus;
assign 	tag_search_bus 			= access_addr_search_i[BW_ACCESS_ADDR-1:BW_WORDS_PER_BLOCK];
assign 	tag_write_bus 			= access_addr_write_i[BW_ACCESS_ADDR-1:BW_WORDS_PER_BLOCK];
assign 	access_addr_search_o 	= {tag_mem[cache_addr_i],{BW_WORDS_PER_BLOCK{1'b0}}};
assign 	hit_o 					= |(matchbits & validbits_reg);

genvar j;
generate 
	for (j = 0; j < N_CAPACITY_BLOCKS; j = j + 1) begin : tag_comparator_array
		identity_comparator #(
			.BW 		(BW_ACCESS_TAG 		)
		) comp_inst(
			.opA_i 		(tag_search_bus 	), 
			.opB_i 		(tag_mem[j] 		), 
			.match_o 	(matchbits[j] 		)
		);
	end
endgenerate

// cache -> access mux
reg 	[BW_CAPACITY_BLOCKS-1:0]addr_reg; 										// address passed from tag -> addr lookup
assign 	cache_addr_search_o 	= addr_reg;

integer k;
always @(*) begin
	addr_reg = 'b0;
	for (k = 0; k < N_CAPACITY_BLOCKS; k = k + 1) begin
		if (matchbits[k] & validbits_reg[k]) begin
			addr_reg = k[BW_CAPACITY_BLOCKS-1:0];
		end
	end
end

// tag memory controller
// -----------------------------------------------------------------------------------------------

integer i;
always @(posedge clock_i) begin
	// reset condition
	if (resetn_i != 1'b1) begin
		validbits_reg <= 'b0;
		for (i = 0; i < N_CAPACITY_BLOCKS; i = i + 1) begin
			tag_mem[i] <= 'b0;
		end
	end
	// active sequencing
	else begin
		if (wren_i == 1'b1) begin
			tag_mem[cache_addr_i] 			<= tag_write_bus;
			validbits_reg[cache_addr_i] 	<= 1'b1;
		end
		if (rmen_i == 1'b1) begin
			validbits_reg[cache_addr_i] 	<= 1'b0;
		end
	end
end

endmodule
`endif 	// _TAG_LOOKUP_TABLE_FA_V_