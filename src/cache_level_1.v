`ifndef _CACHE_LEVEL_1_V_
`define _CACHE_LEVEL_1_V_

module cache_level_1 #(

	parameter BW_CORE_ADDR_BYTE		= 32, 				// byte addressible input address
	parameter BW_USED_ADDR_BYTE 	= 26, 				// byte addressible converted address
	parameter BW_DATA_WORD 			= 32,  				// bits in a data word
	parameter BW_DATA_EXTERNAL_BUS 	= 512, 				// bits that can be transfered between this level cache and next
	parameter BW_CACHE_COMMAND 		= 3,
	parameter CACHE_WORDS_PER_BLOCK = 16, 				// words in a block
	parameter CACHE_CAPACITY_BLOCKS = 128, 				// cache capacity in blocks
	parameter CACHE_ASSOCIATIVITY 	= 0, 				// 0 = fully associative
														// 1 = direct mapped
														// 2 = two way set associative
														// 4 = four way set associative
														// 8 = eight way set associative
														// 16 = sixteen way set associative				
	parameter CACHE_POLICY 			= "",
	parameter BW_CONFIG_REGS 		= 32

	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_USED_ADDR_WORD 	= BW_USED_ADDR_BYTE - 2,
	parameter BW_WORDS_PER_BLOCK 	= `CLOG2(CACHE_WORDS_PER_BLOCK),
	parameter BW_CACHE_ADDR 		= `CLOG2(CACHE_CAPACITY_BLOCKS),
	parameter BW_ADDR_TAG 			= BW_USED_ADDR_WORD - BW_WORDS_PER_BLOCK
	`endif

)(

	// control signals
	input 								clock_control_i,
	input 								clock_rw_i,
	input 								resetn_i,
	input 								stall_i, 		// stall caused by external hardware
	output 								stall_o, 		// stall caused by this cache level

	// metric, control, and misc signals
	input 	[BW_CONFIG_REGS-1:0]		config0_i, 		// cache commands
	input 	[BW_CONFIG_REGS-1:0]		config1_i, 		// cache buffer addresses
	output	[BW_CONFIG_REGS-1:0]		status_o, 		// cache/components status 		
	output 	[BW_CONFIG_REGS-1:0]		config0_o, 		// cache buffer data

	// core/hart signals
	input 								core_request_i,	
	input 								core_wren_i,
	input 	[BW_CORE_ADDR_BYTE-1:0]		core_addr_i,
	input 	[BW_DATA_WORD-1:0] 			core_data_i,
	output 								core_valid_o,
	output 	[BW_DATA_WORD-1:0] 			core_data_o,

	// next level memory signals - from next level
	input 								external_write_i,
	input  	[BW_CACHE_COMMAND-1:0] 		external_command_i,
	input 	[BW_USED_ADDR_WORD-1:0] 	external_addr_i,
	input  	[BW_DATA_EXTERNAL_BUS-1:0] 	external_data_i,
	output 								external_full_o,

	// next level memory signals - to next level
	output 								external_write_o,
	output 	[BW_CACHE_COMMAND-1:0] 		external_command_o,
	output 	[BW_USED_ADDR_WORD-1:0] 	external_addr_o,
	output  [BW_DATA_EXTERNAL_BUS-1:0] 	external_data_o,
	input 								external_full_i
);

// parameterizations
// --------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam BW_USED_ADDR_WORD 	= BW_USED_ADDR_BYTE - 2;
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(CACHE_WORDS_PER_BLOCK);
localparam BW_CACHE_ADDR 		= `CLOG2(CACHE_CAPACITY_BLOCKS);
localparam BW_ADDR_TAG 			= BW_USED_ADDR_WORD - BW_WORDS_PER_BLOCK;
`endif


// data buffer for next level signals (stores incoming signals)
// --------------------------------------------------------------------------------
wire 								buffer_read_flag;
wire								buffer_empty_flag;
wire [BW_CACHE_COMMAND-1:0] 		buffer_command_bus;
wire [BW_USED_ADDR_WORD-1:0] 		buffer_address_bus;
wire [BW_DATA_EXTERNAL_BUS-1:0] 	buffer_data_bus;

cache_request_buffer #(
	.N_ENTRIES 				(2 							), 	// size of the buffer
	.BW_COMMAND 			(BW_CACHE_COMMAND 			),  // size of the command to register
	.BW_ADDR 				(BW_USED_ADDR_WORD 			), 	// size of the address to register
	.BW_DATA 				(BW_DATA_EXTERNAL_BUS 		) 	// size of entire cache line
) cache_request_buffer_inst (
	.clock_i 				(clock_rw_i 				),
	.resetn_i 				(resetn_i 					),
	.write_i 				(external_write_i 			), 	// from higher level memory		
	.command_i 				(external_command_i 		),
	.addr_i  				(external_addr_i 			),
	.data_i  				(external_data_i 			),
	.full_o  				(external_full_o 			),
	.read_i  				(buffer_read_flag 			),	// from this level controller
	.empty_o  				(buffer_empty_flag 			),
	.command_o  			(buffer_command_bus 		),
	.addr_o  				(buffer_address_bus 		),
	.data_o  				(buffer_data_bus 			)
);


// cache tag lookup table
// --------------------------------------------------------------------------------
wire 						tag_memory_write_flag;
wire [BW_ADDR_TAG-1:0]		tag_memory_tag_search_bus, 			// ws mean write/search (muxed)
							tag_memory_tag_write_bus,
							tag_memory_tag_read_bus;
wire [BW_CACHE_ADDR-1:0] 	tag_memory_addr_ws_bus,
							tag_memory_addr_read_bus;
wire 						tag_memory_hit_flag;

tag_lookup_table_fa #(
	.BW_ADDR_SPACE 			(BW_USED_ADDR_WORD 			),
	.CACHE_BLOCK_CAPACITY	(CACHE_CAPACITY_BLOCKS 		),
	.WORDS_PER_BLOCK 		(CACHE_WORDS_PER_BLOCK 		)
) cache_tag_lookup_table_inst (
	.clock_i 				(clock_rw_i 				), 	// write edge
	.resetn_i 				(resetn_i 					), 	// reset active low 		
	.wren_i 				(tag_memory_write_flag 		), 	// write enable (write new entry)
	.rmen_i 				(1'b0 						), 	// remove enable (invalidate entry) 	
	.tag_search_i 			(tag_memory_tag_search_bus 	), 	// primary input (tag -> cache location)
	.tag_write_i 			(tag_memory_tag_write_bus 	),
	.addr_i 				(tag_memory_addr_ws_bus 	), 	// add -> tag (part of absolute memory address) - used for replacement
	.addr_o 				(tag_memory_addr_read_bus 	), 	// primary output (cache location <- tag)
	.tag_o 					(tag_memory_tag_read_bus 	),	// tag <- add
	.hit_o 					(tag_memory_hit_flag 		)	// logic high if lookup hit
);


// cache memory
// --------------------------------------------------------------------------------
wire 							word_write_flag,
								block_write_flag;
wire [BW_CACHE_ADDR-1:0] 		cache_memory_addr_bus;
wire [BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_bus;
wire [BW_DATA_EXTERNAL_BUS-1:0]	cache_memory_data_write_bus,
								cache_memory_data_block_read_bus;
wire [BW_DATA_WORD-1:0]			cache_memory_data_word_read_bus;

cache_memory #(
	.BW_DATA 				(BW_DATA_WORD 	 					), 	// bit width of just 1 data word
	.N_BLOCKS 				(CACHE_CAPACITY_BLOCKS 				), 	// address space
	.N_WORDS_PER_BLOCK		(CACHE_WORDS_PER_BLOCK 				) 	// number of embedded memories needed
) cache_memory_inst (	
	.clock_i 				(clock_rw_i 						),
	.wren_word_i 			(word_write_flag 					),	// execute single word write 
	.wren_block_i 			(block_write_flag 					), 	// execute block write
	.addr_i 				(cache_memory_addr_bus 				), 	// block address
	.offset_i 				(cache_memory_offset_bus			), 	// block offset (which word)
	.data_block_i 			(cache_memory_data_write_bus 		), 	// block bus in
	.data_word_o 			(cache_memory_data_word_read_bus	), 	// data word out
	.data_block_o 			(cache_memory_data_block_read_bus	) 	// block bus out
);


// cache performance controller
// --------------------------------------------------------------------------------
wire [4:0] 	monitor_flag_bus;

/*cache_performance_monitor #(
	.CACHE_STRUCTURE		(CACHE_ASSOCIATIVITY 	),
	.CACHE_REPLACEMENT 		(CACHE_POLICY 			),
	.N_INPUT_FLAGS 			(5 						), 	// {hit,miss,etc.}
	.BW_CONFIG_REGS 		(BW_CONFIG_REGS 		)
) cache_monitor_inst (
	.clock_i 				(clock_rw_i 			),
	.resetn_i 				(resetn_i 				),
	.flags_i 				(monitor_flag_bus 		),
	.config0_i 	 			(config0_i 				), 	// cache control 	[31:16 | 15:0]
	.config1_i 	 			(config1_i 				), 	// buffer control
	.data0_o 	 			(status_o 				), 	// cache data
	.data1_o 	 			(config0_o 				) 	// buffer data
);*/


// cache controller
// --------------------------------------------------------------------------------
cache_fa_controller #(
	.BW_CORE_ADDR_BYTE 		(BW_CORE_ADDR_BYTE 		), 	// byte addressible input address
	.BW_USED_ADDR_WORD 		(BW_USED_ADDR_WORD 		), 	// byte addressible converted address
	.BW_DATA_WORD 			(BW_DATA_WORD 			),  // bits in a data word
	.BW_DATA_EXTERNAL_BUS 	(BW_DATA_EXTERNAL_BUS 	), 	// bits that can be transfered between this level cache and next
	.BW_CACHE_COMMAND 		(BW_CACHE_COMMAND 		),
	.CACHE_WORDS_PER_BLOCK 	(CACHE_WORDS_PER_BLOCK 	), 	// words in a block
	.CACHE_CAPACITY_BLOCKS 	(CACHE_CAPACITY_BLOCKS 	), 	// cache capacity in blocks
	.CACHE_ASSOCIATIVITY 	(CACHE_ASSOCIATIVITY 	),
	.CACHE_POLICY 			(CACHE_POLICY 			),
	.CACHE_INIT_STALL		(1'b0 					)
) cache_controller_inst (

	// generics
	.clock_i 				(clock_control_i 		),
	.clock_rw_i 			(clock_rw_i 			),
	.resetn_i 				(resetn_i 				),
	.stall_i 				(stall_i 				),
	.stall_o 				(stall_o 				),

	// core/hart
	.core_request_i 		(core_request_i 		),	
	.core_wren_i 			(core_wren_i 			),
	.core_addr_i 			(core_addr_i 			),
	.core_data_i 			(core_data_i 			),
	.core_valid_o 			(core_valid_o 			),
	.core_data_o			(core_data_o 			),

	// incoming buffer
	.buffer_read_o 			(buffer_read_flag 		),
	.buffer_empty_i 		(buffer_empty_flag 		),
	.buffer_command_i 		(buffer_command_bus 	),
	.buffer_address_i 		(buffer_address_bus 	),
	.buffer_data_i 			(buffer_data_bus 		),

	// outgoing buffer
	.buffer_write_o			(external_write_o 		),
	.buffer_full_i			(external_full_i 		),
	.buffer_command_o		(external_command_o 	),
	.buffer_address_o		(external_addr_o 		),
	.buffer_data_o			(external_data_o 		),


	// tag lookup table
	.tag_memory_hit_i 		(tag_memory_hit_flag 		),
	.tag_memory_write_o 	(tag_memory_write_flag 		),
	.tag_memory_tag_search_o(tag_memory_tag_search_bus 	),
	.tag_memory_tag_write_o (tag_memory_tag_write_bus 	),
	.tag_memory_addr_o 		(tag_memory_addr_ws_bus 	),
	.tag_memory_addr_i 		(tag_memory_addr_read_bus 	),
	.tag_memory_tag_i 		(tag_memory_tag_read_bus 	),

	// cache memory 
	.cache_memory_word_write_o 	(word_write_flag 					),
	.cache_memory_block_write_o (block_write_flag 					),
	.cache_memory_addr_o 		(cache_memory_addr_bus 				),
	.cache_memory_offset_o 		(cache_memory_offset_bus 			),
	.cache_memory_data_o 		(cache_memory_data_write_bus 		),
	.cache_memory_word_i 		(cache_memory_data_word_read_bus 	),
	.cache_memory_block_i 		(cache_memory_data_block_read_bus 	),

	// metric monitor
	.flag_o 				(monitor_flag_bus 			)

);

endmodule

`endif