`ifndef _CACHE_FA_H_
`define _CACHE_FA_H_

// general libraries/headers
`include "utilities.h"

// source files
`include "../src/cache_level_1.v"
`include "../src/buffers/cache_request_buffer.v"
`include "../src/buffers/hart_request_buffer.v"
`include "../src/memory_tag/tag_lookup_table_fa.v"
`include "../src/comparators/identity_comparator.v"
`include "../src/memory_embedded/memory_embedded.v"
`include "../src/memory_embedded/cache_memory.v"
`include "../src/controllers_cache/cache_fa_controller.v"
`include "../src/controllers_policy/fa_cache_fifo_policy_controller.v"

`endif