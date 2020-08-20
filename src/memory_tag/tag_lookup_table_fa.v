`ifndef _TAG_LOOKUP_TABLE_FA_V_
`define _TAG_LOOKUP_TABLE_FA_V_

module tag_lookup_table_fa #(
	parameter 	BW_ADDR_SPACE 			= 0,
	parameter 	CACHE_BLOCK_CAPACITY 	= 0,
	parameter 	WORDS_PER_BLOCK 		= 0

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


// internal memories
// -----------------------------------------------------------------------------------------------
reg 	[BW_TAG-1:0]				tag_mem 		[0:CACHE_BLOCK_CAPACITY-1];	 	// where block tags are stored
wire 	[CACHE_BLOCK_CAPACITY-1:0]	matchbits;										// high if there is a match
reg		[CACHE_BLOCK_CAPACITY-1:0]	validbits_reg;									// high if tag has been written into tag memory
reg 	[BW_CACHE_ADDR-1:0]			addr_reg; 										// address passed from tag -> addr lookup


// port mappings
// -----------------------------------------------------------------------------------------------
assign hit_o 	= |(matchbits & validbits_reg);
assign addr_o 	= addr_reg;
assign tag_o 	= tag_mem[addr_i];


// tag -> address decoding (asynchronous - combinational)
// -----------------------------------------------------------------------------------------------

// comparator array that produces matchbits
genvar j;
generate 
	for (j = 0; j < CACHE_BLOCK_CAPACITY; j = j + 1'b1) begin : tag_comparator_array

		identity_comparator #(
			.BW 		(BW_TAG 			)
		) comp_inst(
			.opA_i 		(tag_search_i 		), 
			.opB_i 		(tag_mem[j] 		), 
			.match_o 	(matchbits[j] 		)
		);

	end
endgenerate


// tag -> add search out
integer k;
always @(*) begin
	addr_reg = 'b0;
	for (k = 0; k < CACHE_BLOCK_CAPACITY; k = k + 1'b1) begin
		if (matchbits[k] & validbits_reg[k]) begin
			addr_reg = k[BW_CACHE_ADDR-1:0];
		end
	end
end


// write and remove control logic (synchronous)
// -----------------------------------------------------------------------------------------------
integer i;
always @(posedge clock_i) begin
	// reset condition
	if (resetn_i != 1'b1) begin
		validbits_reg <= 'b0;
		for (i = 0; i < CACHE_BLOCK_CAPACITY; i = i + 1'b1) begin
			tag_mem[i] <= 'b0;
		end
	end
	// active sequencing
	else begin
		if (wren_i == 1'b1) begin
			tag_mem[addr_i] 		<= tag_write_i;
			validbits_reg[addr_i] 	<= 1'b1;
		end
		if (rmen_i == 1'b1) begin
			validbits_reg[addr_i] 	<= 1'b0;
		end
	end
end

endmodule

`endif