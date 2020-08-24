`ifndef _TAG_LOOKUP_TABLE_V_
`define _TAG_LOOKUP_TABLE_V_

module tag_lookup_table #(
	// port parameters
	parameter BW_ACCESS_ADDR 		= 0, 	
 	parameter N_WORDS_PER_BLOCK 	= 0, 
 	// design parameters
 	parameter N_CAPACITY_BLOCKS 	= 0, 	
 	parameter ASSOCIATIVITY 		= 0
 	// derived parameters
	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS)
	`endif
)(
	input 							clock_i, 				
	input 							resetn_i, 						
	input 							wren_i, 				
	input 							rmen_i, 				
	input [BW_ACCESS_ADDR-1:0] 		access_addr_search_i, 	
	output[BW_ACCESS_ADDR-1:0] 		access_addr_search_o, 	
	input [BW_ACCESS_ADDR-1:0] 		access_addr_write_i, 	
	input [BW_CAPACITY_BLOCKS-1:0] 	cache_addr_i, 			
	output[BW_CAPACITY_BLOCKS-1:0] 	cache_addr_search_o, 	
	output 							hit_o 					
);

// parameterizations
// -----------------------------------------------------------------------------------------------
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(N_WORDS_PER_BLOCK);
`ifndef SIMULATION_SYNTHESIS
localparam BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS);
`endif

// module instantiations
// -----------------------------------------------------------------------------------------------
generate

	// FULLY ASSOCIATIVE 
	// -------------------------------------------------------------------------------------------
	if (ASSOCIATIVITY == N_CAPACITY_BLOCKS) begin
		tag_lookup_table_fa #(
		 	.BW_ACCESS_ADDR 			(BW_ACCESS_ADDR 		), 	
		 	.N_WORDS_PER_BLOCK 			(N_WORDS_PER_BLOCK 		), 
		 	.N_CAPACITY_BLOCKS 			(N_CAPACITY_BLOCKS 		) 		
		) tag_lookup_table_inst (
			.clock_i 					(clock_i 				), 	
			.resetn_i 					(resetn_i 				), 	
			.wren_i 					(wren_i 				),
			.rmen_i 					(rmen_i 				),
			.access_addr_search_i 		(access_addr_search_i 	), 	
			.access_addr_search_o 		(access_addr_search_o  	), 	
			.access_addr_write_i 		(access_addr_write_i  	), 	
			.cache_addr_i 				(cache_addr_i  	 		), 	 
			.cache_addr_search_o 		(cache_addr_search_o  	), 	
			.hit_o 						(hit_o 		 			)
		);
	end

	// 2/4/8/16-WAY SET ASSOCIATIVE
	// -------------------------------------------------------------------------------------------
	else if ((ASSOCIATIVITY == 2) | (ASSOCIATIVITY == 4) | (ASSOCIATIVITY == 8) | (ASSOCIATIVITY == 16)) begin
		tag_lookup_table_set #(
		 	.BW_ACCESS_ADDR 			(BW_ACCESS_ADDR 		), 	
		 	.N_WORDS_PER_BLOCK 			(N_WORDS_PER_BLOCK 		), 
		 	.N_CAPACITY_BLOCKS 			(N_CAPACITY_BLOCKS 		),
		 	.ASSOCIATIVITY 				(ASSOCIATIVITY 			) 		
		) tag_lookup_table_inst (
			.clock_i 					(clock_i 				), 	
			.resetn_i 					(resetn_i 				),
			.wren_i 					(wren_i 				),
			.rmen_i 					(rmen_i 				),
			.access_addr_search_i 		(access_addr_search_i 	),  
			.access_addr_search_o 		(access_addr_search_o  	), 	
			.access_addr_write_i 		(access_addr_write_i  	), 	
			.cache_addr_i 				(cache_addr_i  	 		), 	 
			.cache_addr_search_o 		(cache_addr_search_o  	), 	
			.hit_o 						(hit_o 		 			)
		);
	end

endgenerate

endmodule
`endif // _TAG_LOOKUP_TABLE_V_