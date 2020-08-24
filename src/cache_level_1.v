`ifndef _CACHE_LEVEL_1_V_
`define _CACHE_LEVEL_1_V_

// notes:
// 	- external data bus width is size of block (words_per_block*bw_word_data)

module cache_level_1 #(
	// port parameters
	parameter BW_ACCESS_ADDR 	= 0, 	
	parameter BW_DATA_WORD 		= 0,
	parameter N_WORDS_PER_BLOCK = 0,
	parameter BW_CACHE_COMMAND 	= 0, 	// cache commands between levels
	parameter BW_CACHE_CONFIG 	= 0, 	// special cache register locations
	// cache design parameters
	parameter N_CAPACITY_BLOCKS = 0,
	parameter ASSOCIATIVITY 	= 0,
	parameter POLICY 			= 0
	// derived parameters
	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_DATA_BLOCK 	= N_WORDS_PER_BLOCK*BW_DATA_WORD
	`endif
)(
	// control signals
	input 								clock_control_i, 	// cache controller
	input 								clock_rw_i, 		// tag and cache memory
	input 								resetn_i,
	input 								stall_i, 			// stall caused by external hardware
	output 								stall_o, 			// stall caused by this cache level
	// metric, control, and misc signals
	input 	[BW_CACHE_CONFIG-1:0] 		config_i, 			// cache/buffer commands
	output 	[BW_CACHE_CONFIG-1:0] 		config_o, 			// data/status out
	// core/hart signals
	input 								core_request_i,	
	input 								core_wren_i,
	input 	[BW_ACCESS_ADDR-1:0]		core_addr_i,
	input 	[BW_DATA_WORD-1:0] 			core_data_i,
	output 								core_valid_o,
	output 	[BW_DATA_WORD-1:0] 			core_data_o,
	// next level memory signals - from next level
	input 								external_write_i,
	input  	[BW_CACHE_COMMAND-1:0] 		external_command_i,
	input 	[BW_ACCESS_ADDR-1:0] 		external_addr_i,
	input  	[BW_DATA_BLOCK-1:0] 		external_data_i,
	output 								external_full_o,
	// next level memory signals - to next level
	output 								external_write_o,
	output 	[BW_CACHE_COMMAND-1:0] 		external_command_o,
	output 	[BW_ACCESS_ADDR-1:0] 		external_addr_o,
	output  [BW_DATA_BLOCK-1:0] 		external_data_o,
	input 								external_full_i
);

// port tie-hi/lows
// --------------------------------------------------------------------------------
assign config_o = 'b0;

// parameterizations
// --------------------------------------------------------------------------------
localparam BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS);
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(N_WORDS_PER_BLOCK);
`ifndef SIMULATION_SYNTHESIS
localparam BW_DATA_BLOCK 		= N_WORDS_PER_BLOCK*BW_DATA_WORD;
`endif


// data buffer for next level signals (stores incoming signals)
// --------------------------------------------------------------------------------
wire 								buffer_read_flag;
wire								buffer_empty_flag;
wire [BW_CACHE_COMMAND-1:0] 		buffer_command_bus;
wire [BW_ACCESS_ADDR-1:0] 			buffer_address_bus;
wire [BW_DATA_BLOCK-1:0] 			buffer_data_bus;

cache_request_buffer #(
	.N_ENTRIES 					(2 									), 	// size of the buffer
	.BW_COMMAND 				(BW_CACHE_COMMAND 					),  // size of the command to register
	.BW_ADDR 					(BW_ACCESS_ADDR 					), 	// size of the address to register
	.BW_DATA 					(BW_DATA_BLOCK 						) 	// size of entire cache line
) cache_request_buffer_inst 	(
	.clock_i 					(clock_rw_i 						),
	.resetn_i 					(resetn_i 							),
	.write_i 					(external_write_i 					), 	// from higher level memory		
	.command_i 					(external_command_i 				),
	.addr_i  					(external_addr_i 					),
	.data_i  					(external_data_i 					),
	.full_o  					(external_full_o 					),
	.read_i  					(buffer_read_flag 					),	// from this level controller
	.empty_o  					(buffer_empty_flag 					),
	.command_o  				(buffer_command_bus 				),
	.addr_o  					(buffer_address_bus 				),
	.data_o  					(buffer_data_bus 					)
);

// cache tag lookup table
// --------------------------------------------------------------------------------
wire 							cam_write_flag;
wire 							cam_hit_flag;
wire [BW_ACCESS_ADDR-1:0] 		cam_access_addr_search_i_bus, 			// access_addr -> cache_addr
								cam_access_addr_search_o_bus; 			// cache_addr -> access_addr
wire [BW_ACCESS_ADDR-1:0] 		cam_access_addr_write_i_bus; 			// access_addr to write
wire [BW_CAPACITY_BLOCKS-1:0] 	cam_cache_addr_i_bus, 					// cache_addr -> access_addr
								cam_cache_addr_search_o_bus; 			// access_addr -> cache_addr

tag_lookup_table #(
 	.BW_ACCESS_ADDR 			(BW_ACCESS_ADDR 					), 	
 	.N_WORDS_PER_BLOCK 			(N_WORDS_PER_BLOCK 					), 
 	.N_CAPACITY_BLOCKS 			(N_CAPACITY_BLOCKS 					), 	
 	.ASSOCIATIVITY 				(ASSOCIATIVITY 						) 	
) tag_lookup_table_inst (
	.clock_i 					(clock_rw_i 						), 	// write edge
	.resetn_i 					(resetn_i 							), 	// reset active low
	.wren_i 					(cam_write_flag 					),
	.rmen_i 					(1'b0 								),
	.access_addr_search_i 		(cam_access_addr_search_i_bus 		), 	// access_addr -> cache_addr
	.access_addr_search_o 		(cam_access_addr_search_o_bus  		), 	// access_addr -> cache_addr 
	.access_addr_write_i 		(cam_access_addr_write_i_bus  		), 	// loc. of where to write tag to
	.cache_addr_i 				(cam_cache_addr_i_bus  				), 	// cache_addr -> access_addr (based on .cache_write_i port)
	.cache_addr_search_o 		(cam_cache_addr_search_o_bus  		), 	// tag to write to tag memory
	.hit_o 						(cam_hit_flag 		 				)
);

// cache memory
// --------------------------------------------------------------------------------
wire 							word_write_flag,
								block_write_flag;
wire [BW_CAPACITY_BLOCKS-1:0] 	cache_memory_addr_bus;
wire [BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_bus;
wire [BW_DATA_BLOCK-1:0]		cache_memory_data_write_bus,
								cache_memory_data_block_read_bus;
wire [BW_DATA_WORD-1:0]			cache_memory_data_word_read_bus;

cache_memory #(
	.BW_DATA 					(BW_DATA_WORD 	 					), 	// bit width of just 1 data word
	.N_BLOCKS 					(N_CAPACITY_BLOCKS 					), 	// address space
	.N_WORDS_PER_BLOCK			(N_WORDS_PER_BLOCK 					) 	// number of embedded memories needed
) cache_memory_inst (	
	.clock_i 					(clock_rw_i 						),
	.wren_word_i 				(word_write_flag 					),	// execute single word write 
	.wren_block_i 				(block_write_flag 					), 	// execute block write
	.addr_i 					(cache_memory_addr_bus 				), 	// block address
	.offset_i 					(cache_memory_offset_bus			), 	// block offset (which word)
	.data_block_i 				(cache_memory_data_write_bus 		), 	// block bus in
	.data_word_o 				(cache_memory_data_word_read_bus	), 	// data word out
	.data_block_o 				(cache_memory_data_block_read_bus	) 	// block bus out
);


// cache performance controller
// --------------------------------------------------------------------------------
//wire [4:0] 	monitor_flag_bus;

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
cache_controller #(
	// port parameters
	.BW_ACCESS_ADDR				(BW_ACCESS_ADDR 					), 	
	.BW_DATA_WORD				(BW_DATA_WORD 						),
	.N_WORDS_PER_BLOCK			(N_WORDS_PER_BLOCK 					),
	.BW_CACHE_COMMAND			(BW_CACHE_COMMAND 					), 	// cache commands between levels
	.BW_CACHE_CONFIG			(BW_CACHE_CONFIG 					), 	// special cache register locations
	// cache design parameters
	.N_CAPACITY_BLOCKS			(N_CAPACITY_BLOCKS 					),
	.ASSOCIATIVITY				(ASSOCIATIVITY 						),
	.POLICY						(POLICY 							)
) cache_controller_inst (
	// generics
	.clock_i 					(clock_control_i 					),
	.clock_rw_i 				(clock_rw_i 						),
	.resetn_i 					(resetn_i 							),
	.stall_i 					(stall_i 							),
	.stall_o 					(stall_o 							),
	// core request
	.core_request_i 			(core_request_i 					),	
	.core_wren_i 				(core_wren_i 						),
	.core_addr_i 				(core_addr_i 						),
	.core_data_i 				(core_data_i 						),
	.core_valid_o 				(core_valid_o 						),
	.core_data_o				(core_data_o 						),
	// incoming buffer
	.buffer_read_o 				(buffer_read_flag 					),
	.buffer_empty_i 			(buffer_empty_flag 					),
	.buffer_command_i 			(buffer_command_bus 				),
	.buffer_address_i 			(buffer_address_bus 				),
	.buffer_data_i 				(buffer_data_bus 					),
	// outgoing buffer
	.buffer_write_o				(external_write_o 					),
	.buffer_full_i				(external_full_i 					),
	.buffer_command_o			(external_command_o 				),
	.buffer_address_o			(external_addr_o 					),
	.buffer_data_o				(external_data_o 					),
	// tag memory
	.cam_write_o 				(cam_write_flag 					),
	.cam_hit_i 					(cam_hit_flag 		 				),
	.cam_access_addr_search_o 	(cam_access_addr_search_i_bus 		), 	// access_addr -> cache_addr
	.cam_access_addr_search_i 	(cam_access_addr_search_o_bus  		), 	// access_addr -> cache_addr 
	.cam_access_addr_write_o 	(cam_access_addr_write_i_bus  		), 	// loc. of where to write tag to
	.cam_cache_addr_o 			(cam_cache_addr_i_bus  				), 	// cache_addr -> access_addr (based on .cache_write_i port)
	.cam_cache_addr_search_i 	(cam_cache_addr_search_o_bus  		), 	// tag to write to tag memory
	// cache memory
	.cache_memory_word_write_o 	(word_write_flag 					),
	.cache_memory_block_write_o (block_write_flag 					),
	.cache_memory_addr_o 		(cache_memory_addr_bus 				),
	.cache_memory_offset_o 		(cache_memory_offset_bus 			),
	.cache_memory_data_o 		(cache_memory_data_write_bus 		),
	.cache_memory_word_i 		(cache_memory_data_word_read_bus 	),
	.cache_memory_block_i 		(cache_memory_data_block_read_bus 	)
	// performance metric
	//.cache_performance_o 		()
);

endmodule

`endif