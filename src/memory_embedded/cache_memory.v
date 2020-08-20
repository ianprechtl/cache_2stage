// block write: wren_block_i = 1
// word write: wren_word_i = 1, word placed in lowest bits of data_block_i

// BW_DATA is per word

`ifndef _CACHE_MEMORY_V_
`define _CACHE_MEMORY_V_

module cache_memory #(
	parameter BW_DATA 			= 0,
	parameter N_BLOCKS 			= 0, 		// address space
	parameter N_WORDS_PER_BLOCK = 0 		// number of embedded memories needed

	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_ADDR 			= `CLOG2(N_BLOCKS), 
	parameter BW_OFFSET 		= `CLOG2(N_WORDS_PER_BLOCK),
	parameter BW_BLOCK 			= BW_DATA*N_WORDS_PER_BLOCK
	`endif
)(	
	input 					clock_i,
	input 					wren_word_i,	// execute single word write 
	input 					wren_block_i, 	// execute block write
	input 	[BW_ADDR-1:0]	addr_i, 		// block address
	input 	[BW_OFFSET-1:0]	offset_i, 		// block offset (which word)
	input 	[BW_BLOCK-1:0]	data_block_i, 	// block bus in
	output 	[BW_DATA-1:0] 	data_word_o, 	// data word out
	output 	[BW_BLOCK-1:0]	data_block_o 	// block bus out
);

// parameterizations
// ----------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam BW_ADDR 		= `CLOG2(N_BLOCKS); 
localparam BW_OFFSET 	= `CLOG2(N_WORDS_PER_BLOCK);
localparam BW_BLOCK 	= BW_DATA*N_WORDS_PER_BLOCK;
`endif

// memory input logic
// ----------------------------------------------------------------------------------
wire [N_WORDS_PER_BLOCK-1:0]	wren_bus; 		
wire [BW_DATA-1:0] 				data_write_bus	[0:N_WORDS_PER_BLOCK-1]; 
wire [BW_DATA-1:0] 				data_read_bus	[0:N_WORDS_PER_BLOCK-1]; 

// encode offset as one hot signal - write enable for memory array
wire [N_WORDS_PER_BLOCK-1:0] 	offset_encoding_bus;

assign offset_encoding_bus = 1'b1 << offset_i;


// memory instantiations 
// ----------------------------------------------------------------------------------
genvar g;
generate
	for (g = 0; g < N_WORDS_PER_BLOCK; g = g + 1) begin: cache_memory_arr

		// write enable
		// ----------------------------------------------
		assign wren_bus[g] = wren_block_i | (offset_encoding_bus[g] & wren_word_i);

		// write in data
		// ----------------------------------------------
		assign data_write_bus[g] = (wren_block_i) 	? data_block_i[(BW_DATA*g)+(BW_DATA-1):BW_DATA*g] 
													: data_block_i[BW_DATA-1:0];

		// memory component
		// ----------------------------------------------
		memory_embedded #(
			.N_ENTRIES 	(N_BLOCKS 			),
			.BW_DATA 	(BW_DATA 			),
			.DEBUG 		(0 					),
			.INIT_PATH 	("" 				) 
		) memory_embedded_inst (
			.clock_i 	(clock_i 			),
			.wren_i 	(wren_bus[g] 		),
			.addr_i 	(addr_i 			),
			.data_i 	(data_write_bus[g]	),
			.data_o 	(data_read_bus[g]	)
		);

		// direct route to block output bus
		// ----------------------------------------------
		assign data_block_o[(BW_DATA*g)+(BW_DATA-1):BW_DATA*g] = data_read_bus[g];

	end
endgenerate


// memory output logic
// ----------------------------------------------------------------------------------
reg [BW_DATA-1:0] 	data_read_reg;
integer i;

assign data_word_o = data_read_reg;

always @(*) begin
	data_read_reg <= 'b0;
	for (i = 0; i < N_WORDS_PER_BLOCK; i = i + 1) begin
		if (offset_i == i[BW_OFFSET-1:0]) data_read_reg <= data_read_bus[i];
	end
end

`endif

endmodule