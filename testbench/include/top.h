`ifndef _TOP_H_
`define _TOP_H_

// simulation/emulation control
`define SIMULATION_SYNTHESIS

// macro/function libraries
`include "../../include/utilities.h"

// top level libraries and source
`include "../../include/cache.h"
`include "../src/test_memory_controller.v"

// top-level configurations
`define TOP_BW_CORE_ADDR 			24
`define TOP_BW_DATA_WORD 			32
`define TOP_BW_CACHE_COMMAND 		3
`define TOP_CACHE_WORDS_PER_BLOCK 	16
`define TOP_BW_DATA_BLOCK 			`TOP_CACHE_WORDS_PER_BLOCK*`TOP_BW_DATA_WORD
`define TOP_BW_CONFIG_REGS 			1

`define TOP_CACHE_CAPACITY_BLOCKS  	128
`define TOP_CACHE_ASSOCIATIVITY 	128
`define TOP_CACHE_POLICY 			`CACHE_POLICY_ID_FIFO

`define TOP_BW_RAM 					16
`define TOP_MEMORY_PATH 			"memory.mif"

`endif