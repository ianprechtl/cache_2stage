`ifndef _TAG_LOOKUP_TABLE_SET_V_
`define _TAG_LOOKUP_TABLE_SET_V_

module tag_lookup_table_set #(
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
`ifndef SIMULATION_SYNTHESIS
localparam BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS);
`endif
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(N_WORDS_PER_BLOCK);
localparam BW_ACCESS_SET 		= `CLOG2(ASSOCIATIVITY);
localparam BW_ACCESS_GROUP 		= BW_CAPACITY_BLOCKS - BW_ACCESS_SET;
localparam BW_ACCESS_TAG 		= BW_ACCESS_ADDR - BW_ACCESS_GROUP - BW_WORDS_PER_BLOCK;


// access_addr <-> cache_addr translations
// -----------------------------------------------------------------------------------------------
reg 	[BW_ACCESS_TAG-1:0]	tag_mem 		[0:ASSOCIATIVITY-1][0:(2**BW_ACCESS_GROUP)-1]; 
wire 	[ASSOCIATIVITY-1:0] matchbits;
wire 	[ASSOCIATIVITY-1:0]	hitbits;
reg 						validbits_reg 	[0:ASSOCIATIVITY-1][0:(2**BW_ACCESS_GROUP)-1];

wire [BW_ACCESS_GROUP-1:0] 	access_grp = access_addr_search_i[BW_WORDS_PER_BLOCK+:BW_ACCESS_GROUP];
wire [BW_ACCESS_TAG-1:0] 	access_tag = access_addr_search_i[BW_ACCESS_ADDR-1:BW_ACCESS_GROUP+BW_WORDS_PER_BLOCK];

// access_addr -> cache_addr
genvar g;
generate
	for (g = 0; g < ASSOCIATIVITY; g = g + 1) begin : gen0
		wire [BW_ACCESS_TAG-1:0] tag_memory_vec;
		assign tag_memory_vec 	= tag_mem[g][access_grp];
		assign matchbits[g] 	= (tag_memory_vec == access_tag) ? 1'b1 : 1'b0;
		assign hitbits[g] 		= matchbits[g] & validbits_reg[g][access_grp];
	end
endgenerate

reg [BW_CAPACITY_BLOCKS-1:0] cache_addr_search_o_reg;
assign cache_addr_search_o = cache_addr_search_o_reg;
assign hit_o = |hitbits;

integer i;
always @(*) begin
	cache_addr_search_o_reg = 'b0;
	for (i = 0; i < ASSOCIATIVITY; i = i + 1) begin
		if (hitbits[i]) cache_addr_search_o_reg = {i[BW_ACCESS_SET-1:0],access_grp};
	end
end


// cache_addr -> access_addr
wire [BW_ACCESS_SET-1:0] 	cache_addr_set;
wire [BW_ACCESS_GROUP-1:0] 	cache_addr_grp;

assign  cache_addr_set = cache_addr_i[BW_CAPACITY_BLOCKS-1:BW_ACCESS_GROUP];
assign 	cache_addr_grp = cache_addr_i[BW_ACCESS_GROUP-1:0];

assign 	access_addr_search_o = {tag_mem[cache_addr_set][cache_addr_grp],cache_addr_grp,{BW_WORDS_PER_BLOCK{1'b0}} };


// tag memory controller
// -----------------------------------------------------------------------------------------------
integer x,y;

always @(posedge clock_i) begin
	// reset state
	if (!resetn_i) begin
		for (x = 0; x < (2**BW_ACCESS_GROUP); x = x + 1) begin
			for (y = 0; y < ASSOCIATIVITY; y = y + 1) begin
				tag_mem[y][x] 		<= 'b0;
				validbits_reg[y][x] <= 1'b0;
			end
		end
	end
	// active sequencing
	else begin
		// write control
		if (wren_i) begin
			tag_mem[cache_addr_set][cache_addr_grp] 		<= access_addr_write_i[BW_ACCESS_ADDR-1:BW_ACCESS_GROUP+BW_WORDS_PER_BLOCK];
			validbits_reg[cache_addr_set][cache_addr_grp] 	<= 1'b1;
		end
		// remove control
		if (rmen_i) begin
			validbits_reg[cache_addr_set][cache_addr_grp] 	<= 1'b0;
		end
	end
end

endmodule

`endif // _TAG_LOOKUP_TABLE_SET_V_