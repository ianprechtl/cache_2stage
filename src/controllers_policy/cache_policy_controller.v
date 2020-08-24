`ifndef _CACHE_POLICY_CONTROLLER_V_
`define _CACHE_POLICY_CONTROLLER_V_

module cache_policy_controller #(
	// port parameters
	parameter BW_ACCESS_ADDR 	= 0,
	// design parameters
	parameter N_CAPACITY_BLOCKS = 0,
	parameter N_WORDS_PER_BLOCK = 0,
	parameter ASSOCIATIVITY 	= 0,
	parameter POLICY 			= 0 	
	// derived parameters
	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_CAPACITY_BLOCKS = `CLOG2(N_CAPACITY_BLOCKS)
	`endif
)(
	input 								clock_i,
	input 								resetn_i,
	input 	[BW_ACCESS_ADDR-1:0] 		access_addr_i,
	input 	[BW_CAPACITY_BLOCKS-1:0] 	cache_addr_i, 		// req. address to update policy
 	input 								miss_i, 		// pulse trigger to generate a replacement address
	input 								hit_i, 			// pulse trigger to update policy
	output 								done_o, 		// logic high when replacement address generated
	output 	[BW_CAPACITY_BLOCKS-1:0] 	addr_o  		// replacement address generated
);

// parameterization
// ----------------------------------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam BW_CAPACITY_BLOCKS = `CLOG2(N_CAPACITY_BLOCKS);
`endif

// policy controller instantiations
// ----------------------------------------------------------------------------------------------------------
generate
	
	// FIFO REPLACEMENT
	// ------------------------------------------------------------------------------------------------------
	if (POLICY == `CACHE_POLICY_ID_FIFO) begin
		cache_policy_controller_fifo #(
			.BW_ACCESS_ADDR  	(BW_ACCESS_ADDR 	),
			.N_CAPACITY_BLOCKS	(N_CAPACITY_BLOCKS	),
			.N_WORDS_PER_BLOCK 	(N_WORDS_PER_BLOCK 	),
			.ASSOCIATIVITY 		(ASSOCIATIVITY 		)
		)cache_policy_controller_inst(
			.clock_i			(clock_i 			),
			.resetn_i			(resetn_i 			),
			.access_addr_i		(access_addr_i 		), 		// req. address to update policy
			.cache_addr_i 		(cache_addr_i 		),
		 	.miss_i				(miss_i 			), 		// pulse trigger to generate a replacement address
			.hit_i				(hit_i 				), 		// pulse trigger to update policy
			.done_o				(done_o 			), 		// logic high when replacement address generated
			.addr_o				(addr_o 			)  		// replacement address generated
		);
	end

endgenerate

endmodule

`endif // _CACHE_POLICY_CONTROLLER_V_