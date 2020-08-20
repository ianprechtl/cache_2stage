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


`endif