`ifndef _TOP_H_
`define _TOP_H_

// simulation/emulation control
`define SIMULATION_SYNTHESIS

// top-level configurations
`define TOP_BW_CORE_ADDR_BYTE	 	32 				// byte addressible input address
`define TOP_BW_USED_ADDR_BYTE  		26 				// byte addressible converted address
`define TOP_BW_DATA_WORD 		 	32  			// bits in a data word
`define TOP_BW_DATA_EXTERNAL_BUS 	512 			// bits that can be transfered between this level cache and next
`define TOP_BW_CACHE_COMMAND 		3
`define TOP_CACHE_WORDS_PER_BLOCK  	16 				// words in a block
`define TOP_CACHE_CAPACITY_BLOCKS  	128 			// cache capacity in blocks
`define TOP_CACHE_ASSOCIATIVITY 	0 				// 0 = fully associative
													// 1 = direct mapped
													// 2 = two way set associative
													// 4 = four way set associative
													// 8 = eight way set associative
													// 16 = sixteen way set associative		
`define TOP_CACHE_POLICY 			""
`define TOP_BW_CONFIG_REGS 			32
`define TOP_BW_RAM_ADDR_WORD 		16
`define TOP_BW_USED_ADDR_WORD 		`TOP_BW_USED_ADDR_BYTE - 2

`define TOP_MEMORY_PATH 			"memory.mif"

// macro/function libraries
`include "../../include/utilities.h"

// top level libraries and source
`include "../../include/cache.h"
`include "../../include/cache_fa.h"
`include "../src/test_memory_controller.v"

`endif