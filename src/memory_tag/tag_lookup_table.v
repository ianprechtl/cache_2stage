`ifndef _TAG_LOOKUP_TABLE_V_
`define _TAG_LOOKUP_TABLE_V_

module tag_lookup_table #(
	parameter 	BW_ADDR_SPACE 			= 0,
	parameter 	CACHE_BLOCK_CAPACITY 	= 0,
	parameter 	WORDS_PER_BLOCK 		= 0,
	parameter 	N_WAY 					= 0

	`ifdef SIMULATION_SYNTHESIS ,
	parameter 	BW_CACHE_ADDR 			= `CLOG2(CACHE_BLOCK_CAPACITY),
	parameter 	BW_WORDS_PER_BLOCK 		= `CLOG2(WORDS_PER_BLOCK),
	parameter 	BW_TAG 					= BW_ADDR_SPACE - BW_WORDS_PER_BLOCK
	`endif
)(
	input 						clock_i, 		// write edge
	input 						resetn_i, 		// reset active low 		
	input 						wren_i, 		// write enable (write new entry)
	input 						rmen_i, 		// remove enable (invalidate entry) 	
	input 	[BW_TAG-1:0]		tag_search_i, 	// primary input (tag -> cache location)
	input 	[BW_TAG-1:0] 		tag_write_i, 	// secondary port (for writing to the lookup table)
	input 	[BW_CACHE_ADDR-1:0]	addr_i, 		// produces tag of given address and is used for writing to the lookup table
	output	[BW_CACHE_ADDR-1:0]	addr_o, 		// primary output (cache location <- tag)
	output 	[BW_TAG-1:0]		tag_o,			// tag <- add
	output 						hit_o 			// logic high if lookup hit	
);

// parameterizations
// -----------------------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam 	BW_CACHE_ADDR 		= `CLOG2(CACHE_BLOCK_CAPACITY);
localparam 	BW_WORDS_PER_BLOCK 	= `CLOG2(WORDS_PER_BLOCK);
localparam 	BW_TAG 				= BW_ADDR_SPACE - BW_WORDS_PER_BLOCK;
`endif

// module instantiations
// -----------------------------------------------------------------------------------------------
generate

	// FULLY ASSOCIATIVE 
	// -------------------------------------------------------------------------------------------
	if (N_WAY == CACHE_BLOCK_CAPACITY) begin
		tag_lookup_table_fa #(
	 		.BW_ADDR_SPACE 			(BW_ADDR_SPACE 			),
	 		.CACHE_BLOCK_CAPACITY 	(CACHE_BLOCK_CAPACITY	),
	 		.WORDS_PER_BLOCK 		(WORDS_PER_BLOCK 		)
		)tag_inst(
			.clock_i				(clock_i 				), 		// write edge
			.resetn_i				(resetn_i 				), 		// reset active low 		
			.wren_i					(wren_i 				), 		// write enable (write new entry)
			.rmen_i					(rmen_i 				), 		// remove enable (invalidate entry) 	
			.tag_search_i			(tag_search_i 			), 		// primary input (tag -> cache location)
			.tag_write_i			(tag_write_i 			), 		// secondary port (for writing to the lookup table)
			.addr_i					(addr_i 				), 		// produces tag of given address and is used for writing to the lookup table
			.addr_o					(addr_o 				), 		// primary output (cache location <- tag)
			.tag_o					(tag_o 					),		// tag <- add
			.hit_o					(hit_o 					) 		// logic high if lookup hit
		);
	end

	// 2-WAY SET ASSOCIATIVE
	// -------------------------------------------------------------------------------------------

	// 4-WAY SET ASSOCIATIVE
	// -------------------------------------------------------------------------------------------

	// 8-WAY SET ASSOCIATIVE
	// -------------------------------------------------------------------------------------------

endgenerate

endmodule
`endif // _TAG_LOOKUP_TABLE_V_