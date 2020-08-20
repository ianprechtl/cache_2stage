`include "../include/top.h"

module top (

	// generics
	input 								clock_control_i,
	input 								clock_rw_i,
	input 								resetn_i,
	output 								stall_o,

	// drivers
	input 								core_request_i,	
	input 								core_wren_i,
	input 	[`TOP_BW_CORE_ADDR_BYTE-1:0]core_addr_i,
	input 	[`TOP_BW_DATA_WORD-1:0] 	core_data_i,

	// sinks
	output 								core_valid_o,
	output 	[`TOP_BW_DATA_WORD-1:0] 	core_data_o

);

// cache controller
// -----------------------------------------------------------------------------------------------------------------------------------------------
wire 									external_write_in_bus;
wire  	[`TOP_BW_CACHE_COMMAND-1:0] 	external_command_in_bus;
wire 	[`TOP_BW_USED_ADDR_WORD-1:0] 	external_addr_in_bus;
wire  	[`TOP_BW_DATA_EXTERNAL_BUS-1:0] external_data_in_bus;
wire 									external_full_in_bus; 

wire 									external_write_out_bus;
wire  	[`TOP_BW_CACHE_COMMAND-1:0] 	external_command_out_bus;
wire 	[`TOP_BW_USED_ADDR_WORD-1:0] 	external_addr_out_bus;
wire  	[`TOP_BW_DATA_EXTERNAL_BUS-1:0] external_data_out_bus;
wire 									external_full_out_bus; 

cache_level_1 #(
	.BW_CORE_ADDR_BYTE 		(`TOP_BW_CORE_ADDR_BYTE 	), 		// byte addressible input address
	.BW_USED_ADDR_BYTE 		(`TOP_BW_USED_ADDR_BYTE 	), 		// byte addressible converted address
	.BW_DATA_WORD 			(`TOP_BW_DATA_WORD 			),  	// bits in a data word
	.BW_DATA_EXTERNAL_BUS 	(`TOP_BW_DATA_EXTERNAL_BUS 	), 		// bits that can be transfered between this level cache and next
	.BW_CACHE_COMMAND 		(`TOP_BW_CACHE_COMMAND 		),
	.CACHE_WORDS_PER_BLOCK 	(`TOP_CACHE_WORDS_PER_BLOCK ), 		// words in a block
	.CACHE_CAPACITY_BLOCKS 	(`TOP_CACHE_CAPACITY_BLOCKS ), 		// cache capacity in blocks
	.CACHE_ASSOCIATIVITY 	(`TOP_CACHE_ASSOCIATIVITY 	),				
	.CACHE_POLICY 			(`TOP_CACHE_POLICY 			),
	.BW_CONFIG_REGS 		(`TOP_BW_CONFIG_REGS 		)
)cache_level_1_inst (

	// control signals
	.clock_control_i 		(clock_control_i 		),
	.clock_rw_i 			(clock_rw_i 		 	),
	.resetn_i 		 		(resetn_i 			 	),
	.stall_i 				(1'b0 					), 		// stall caused by external hardware
	.stall_o 				(stall_o 			 	), 		// stall caused by this cache level

	// metric, control, and misc signals
	.config0_i 				('b0 					), 		// cache commands
	.config1_i 				('b0 					), 		// cache buffer addresses
	.status_o				( 						), 		// cache/components status 		
	.config0_o 				( 						), 		// cache buffer data

	// core/hart signals
	.core_request_i 	 	(core_request_i 		),	
	.core_wren_i 	 		(core_wren_i 			),
	.core_addr_i 	 		(core_addr_i 			),
	.core_data_i 	 		(core_data_i 			),
	.core_valid_o 	 		(core_valid_o 			),
	.core_data_o 	 		(core_data_o 			),

	// next level memory signals - from next level
	.external_write_i 		(external_write_in_bus 	),
	.external_command_i 	(external_command_in_bus),
	.external_addr_i 		(external_addr_in_bus 	),
	.external_data_i 		(external_data_in_bus 	),
	.external_full_o 		(external_full_in_bus 	),

	// next level memory signals - to next level
	.external_write_o 		(external_write_out_bus	),
	.external_command_o 	(external_command_out_bus),
	.external_addr_o 		(external_addr_out_bus	),
	.external_data_o 		(external_data_out_bus	),
	.external_full_i 		(external_full_out_bus	)
);


// external memory controller
// -----------------------------------------------------------------------------------------------------------------------------------------------
wire 							memory_wren;
wire [`TOP_BW_RAM_ADDR_WORD-1:0]memory_addr;
wire [`TOP_BW_DATA_WORD-1:0] 	memory_write_data;
wire [`TOP_BW_DATA_WORD-1:0] 	memory_read_data;

test_memory_controller #(
	.BW_RAM_ADDR_WORD 		(`TOP_BW_RAM_ADDR_WORD 		),
	.BW_USED_ADDR_BYTE 		(`TOP_BW_USED_ADDR_BYTE 	), 		// byte addressible converted address
	.BW_DATA_WORD 			(`TOP_BW_DATA_WORD 			),  	// bits in a data word
	.BW_DATA_EXTERNAL_BUS 	(`TOP_BW_DATA_EXTERNAL_BUS 	), 		// bits that can be transfered between this level cache and next
	.BW_CACHE_COMMAND 		(`TOP_BW_CACHE_COMMAND 		),
	.CACHE_WORDS_PER_BLOCK 	(`TOP_CACHE_WORDS_PER_BLOCK ), 		// words in a block
	.CACHE_CAPACITY_BLOCKS 	(`TOP_CACHE_CAPACITY_BLOCKS ), 		// cache capacity in blocks
	.CACHE_ASSOCIATIVITY 	(`TOP_CACHE_ASSOCIATIVITY 	),				
	.CACHE_POLICY 			(`TOP_CACHE_POLICY 			),
	.BW_CONFIG_REGS 		(`TOP_BW_CONFIG_REGS 		)
) test_memory_controller_inst (

	// generics
	.clock_i 		 		(clock_control_i 		),
	.clock_rw_i 	 		(clock_rw_i 			),
	.resetn_i 		 		(resetn_i 				),

	// to previous level (level 1)
	.external_write_o 		(external_write_in_bus 	),
	.external_command_o 	(external_command_in_bus),
	.external_addr_o 		(external_addr_in_bus 	),
	.external_data_o 		(external_data_in_bus 	),
	.external_full_i 		(external_full_in_bus 	),

	// from previous level (level 1)
	.external_write_i 		(external_write_out_bus	),
	.external_command_i 	(external_command_out_bus),
	.external_addr_i 		(external_addr_out_bus	),
	.external_data_i 		(external_data_out_bus	),
	.external_full_o 		(external_full_out_bus	),

	// main memory									
	.main_wren_o 			(memory_wren 			),
	.main_addr_o 			(memory_addr 			),
	.main_data_o 			(memory_write_data 		),
	.main_data_i 			(memory_read_data 		)

);

// external memory
// -----------------------------------------------------------------------------------------------------------------------------------------------
memory_embedded #(
	.N_ENTRIES 	(2**`TOP_BW_RAM_ADDR_WORD 	),
	.BW_DATA 	(`TOP_BW_DATA_WORD 			),
	.DEBUG 		(0 							), 	// if 1 sets the BRAM to dual port for in memory content editor
	.INIT_PATH 	(`TOP_MEMORY_PATH 			) 	// memory to initialize to
) synthetic_external_memory_inst (
	.clock_i 	(clock_rw_i 				),
	.wren_i 	(memory_wren 				),
	.addr_i 	(memory_addr 				),
	.data_i 	(memory_write_data 			),
	.data_o 	(memory_read_data 			)
);


endmodule