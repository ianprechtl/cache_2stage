`ifndef _CACHE_H_
`define _CACHE_H_


// cache commands
// -------------------------------------------------------------------------
`define CACHE_CMD_BW 						3
`define CACHE_REQUEST_READIN_BLOCK 			3'b000
`define CACHE_REQUEST_WRITEOUT_BLOCK 		3'b001
`define CACHE_REQUEST_READIN_WORD 			3'b010
`define CACHE_REQUEST_WRITEOUT_WORD 		3'b011
`define CACHE_SERVICE_READIN_BLOCK 			3'b000
`define CACHE_SERVICE_WRITEOUT_BLOCK 		3'b001
`define CACHE_SERVICE_READIN_WORD 			3'b010
`define CACHE_SERVICE_WRITEOUT_WORD 		3'b011


// cache policy ID's
// -------------------------------------------------------------------------
`define CACHE_POLICY_ID_RANDOM  			32'h00000000
`define CACHE_POLICY_ID_FIFO 				32'h00000001


// cache identification pins
// -------------------------------------------------------------------------
`define ID_CACHE_RANDOM 					32'h00000000
`define ID_CACHE_FIFO 						32'h00000001
`define ID_CACHE_LRU 						32'h00000002
`define ID_CACHE_MRU 						32'h00000003
`define ID_CACHE_PLRU	 					32'h00000004
`define ID_CACHE_SRRIP	 					32'h00000005
`define ID_CACHE_LEASE 						32'h00000006
`define ID_CACHE_LEASE_DUAL 				32'h00000007
`define ID_CACHE_SAMPLER 					32'h0000000F

`define ID_CACHE_FULLY_ASSOCIATIVE 			32'h00000000
`define ID_CACHE_1WAY_SET_ASSOCIATIVE 		32'h10000000
`define ID_CACHE_2WAY_SET_ASSOCIATIVE 		32'h20000000
`define ID_CACHE_4WAY_SET_ASSOCIATIVE 		32'h40000000
`define ID_CACHE_8WAY_SET_ASSOCIATIVE 		32'h80000000

// generic source files
`include "../src/cache_level_1.v"
`include "../src/buffers/cache_request_buffer.v"
`include "../src/buffers/hart_request_buffer.v"
`include "../src/memory_tag/tag_lookup_table.v"
`include "../src/comparators/identity_comparator.v"
`include "../src/memory_embedded/memory_embedded.v"
`include "../src/memory_embedded/cache_memory.v"
`include "../src/controllers_cache/cache_controller.v"
`include "../src/controllers_policy/cache_policy_controller.v"

// fully associative source files
`include "../src/memory_tag/tag_lookup_table_fa.v"

// set associative source files
`include "../src/memory_tag/tag_lookup_table_set.v"

// replacement policy source files
`include "../src/controllers_policy/cache_policy_controller_fifo.v"

`endif