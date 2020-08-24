`ifndef _CACHE_CONTROLLER_V_
`define _CACHE_CONTROLLER_V_

module cache_controller #(
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
	parameter BW_WORDS_PER_BLOCK= `CLOG2(N_WORDS_PER_BLOCK),
	parameter BW_DATA_BLOCK 	= N_WORDS_PER_BLOCK*BW_DATA_WORD,
	parameter BW_CAPACITY_BLOCKS= `CLOG2(N_CAPACITY_BLOCKS)
	`endif
)(
	// generics
	input 								clock_i,
	input 								clock_rw_i,
	input 								resetn_i,
	input 								stall_i,
	output 								stall_o,
	// core/hart
	input 								core_request_i,	
	input 								core_wren_i,
	input 	[BW_ACCESS_ADDR-1:0]		core_addr_i,
	input 	[BW_DATA_WORD-1:0] 			core_data_i,
	output 								core_valid_o,
	output 	[BW_DATA_WORD-1:0] 			core_data_o,
	// incoming buffer
	output 								buffer_read_o,
	input 								buffer_empty_i,
	input 	[BW_CACHE_COMMAND-1:0]		buffer_command_i,
	input 	[BW_ACCESS_ADDR-1:0] 		buffer_address_i,
	input 	[BW_DATA_BLOCK-1:0] 		buffer_data_i,
	// outgoing buffer
	output 								buffer_write_o,
	input 								buffer_full_i,
	output 	[BW_CACHE_COMMAND-1:0]		buffer_command_o,
	output 	[BW_ACCESS_ADDR-1:0]		buffer_address_o,
	output 	[BW_DATA_BLOCK-1:0]			buffer_data_o,
	// tag lookup table
	output 								cam_write_o,
	input 								cam_hit_i,
	output 	[BW_ACCESS_ADDR-1:0] 		cam_access_addr_search_o,
	input 	[BW_ACCESS_ADDR-1:0] 		cam_access_addr_search_i,
	output 	[BW_ACCESS_ADDR-1:0] 		cam_access_addr_write_o,
	output 	[BW_CAPACITY_BLOCKS-1:0] 	cam_cache_addr_o,
	input 	[BW_CAPACITY_BLOCKS-1:0] 	cam_cache_addr_search_i,
	// cache memory 
	output 								cache_memory_word_write_o,
	output 								cache_memory_block_write_o,
	output 	[BW_CAPACITY_BLOCKS-1:0]	cache_memory_addr_o,
	output 	[BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_o,
	output 	[BW_DATA_BLOCK-1:0] 		cache_memory_data_o,
	input 	[BW_DATA_WORD-1:0] 			cache_memory_word_i,
	input 	[BW_DATA_BLOCK-1:0] 		cache_memory_block_i

	// metric monitor
	//output 	[BW_CACHE_CONFIG-1:0] 		cache_performance_o

);

// parameterization
// ----------------------------------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(N_WORDS_PER_BLOCK);
localparam BW_DATA_BLOCK 		= N_WORDS_PER_BLOCK*BW_DATA_WORD;
localparam BW_CAPACITY_BLOCKS 	= `CLOG2(N_CAPACITY_BLOCKS);
`endif


// core request buffer
// ----------------------------------------------------------------------------------------------------------
//wire 	[BW_ACCESS_ADDR-1:0] 	core_addr_bus;
wire 							wren_request_buffer;
wire 	[BW_ACCESS_ADDR-1:0]	addr_request_buffer;
wire 	[BW_DATA_WORD-1:0] 		data_request_buffer;
wire 							empty_request_buffer;
reg 							read_request_buffer_reg;

hart_request_buffer #(
	.N_ENTRIES		(4 							),
	.BW_ADDR 		(BW_ACCESS_ADDR 			),
	.BW_DATA 		(BW_DATA_WORD 				)
) request_buffer_inst (
	.clock_i 		(clock_rw_i 				),
	.resetn_i 		(resetn_i 					),
	.wren_i 		(core_wren_i 				),
	.addr_i 		(core_addr_i 				),
	.data_i 		(core_data_i 				),
	.write_i 		(core_request_i 			),
	.full_o 		( 							),
	.wren_o 		(wren_request_buffer 		),
	.addr_o 		(addr_request_buffer 		),
	.data_o 		(data_request_buffer 		),
	.read_i 		(read_request_buffer_reg 	),
	.empty_o 		(empty_request_buffer 		)
);

// signal routing
// ----------------------------------------------------------------------------------------------------------

// generics
// -----------------------------
reg 								stall_reg;
assign stall_o = stall_reg;

// core/hart
// -----------------------------
reg 								core_valid_reg;
reg 								core_data_mux_reg;
reg 	[BW_DATA_WORD-1:0] 			core_data_reg;
assign core_valid_o 	= core_valid_reg;
assign core_data_o 		= (!core_data_mux_reg) ? cache_memory_word_i : core_data_reg;


// buffer signals
// -----------------------------
reg 								buffer_read_reg;
reg 								buffer_write_reg;
reg 	[BW_CACHE_COMMAND-1:0]		buffer_command_reg;
reg 	[BW_ACCESS_ADDR-1:0]		buffer_address_reg;
reg 	[BW_DATA_BLOCK-1:0]			buffer_data_reg;

assign buffer_read_o 	= buffer_read_reg;
assign buffer_write_o 	= buffer_write_reg;
assign buffer_command_o = buffer_command_reg;
assign buffer_address_o = buffer_address_reg;
assign buffer_data_o 	= buffer_data_reg;

// tag lookup table
// -----------------------------
reg 								tag_memory_write_reg;
reg 								tag_memory_search_mux_reg;
reg 	[BW_ACCESS_ADDR-1:0]		tag_memory_tag_search_reg,
									tag_memory_tag_write_reg;
reg 	[BW_CAPACITY_BLOCKS-1:0] 	tag_memory_addr_reg;

assign cam_write_o 				= tag_memory_write_reg;
assign cam_access_addr_write_o 	= tag_memory_tag_write_reg;
assign cam_cache_addr_o 		= tag_memory_addr_reg;
assign cam_access_addr_search_o = (!tag_memory_search_mux_reg) ? core_addr_i : tag_memory_tag_search_reg;


// cache memory
// -----------------------------
reg 								cache_memory_word_write_reg;
reg 								cache_memory_block_write_reg;
reg 	[BW_CAPACITY_BLOCKS-1:0]	cache_memory_addr_reg;
reg 	[BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_reg;
reg 	[BW_DATA_BLOCK-1:0] 		cache_memory_data_reg;

assign cache_memory_word_write_o 	= cache_memory_word_write_reg;
assign cache_memory_block_write_o 	= cache_memory_block_write_reg;
assign cache_memory_addr_o 			= cache_memory_addr_reg;
assign cache_memory_offset_o 		= cache_memory_offset_reg;
assign cache_memory_data_o 			= cache_memory_data_reg;

// metric monitor
// -----------------------------
reg 								hit_flag_reg,
									miss_flag_reg,
									writeback_flag_reg;


// policy controller
// ----------------------------------------------------------------------------------------------------------
wire 							replacement_done_flag;
wire [BW_CAPACITY_BLOCKS-1:0] 	replacement_ptr_bus;

reg [BW_ACCESS_ADDR-1:0]		request_addr_reg; 			// forward define for modelsim

cache_policy_controller #(
	.BW_ACCESS_ADDR  		(BW_ACCESS_ADDR 		),
	.N_CAPACITY_BLOCKS 		(N_CAPACITY_BLOCKS 		),
	.N_WORDS_PER_BLOCK 		(N_WORDS_PER_BLOCK 		),
	.ASSOCIATIVITY 			(ASSOCIATIVITY 			),
	.POLICY 				(POLICY 				)
) cache_policy_controller_inst (
	.clock_i 				(clock_rw_i 			),
	.resetn_i 				(resetn_i 				),
	.access_addr_i 			(request_addr_reg 		),
	.cache_addr_i 			(cache_memory_addr_reg 	),
	.miss_i 				(miss_flag_reg 			), 		// pulse trigger to generate a replacement address
	.hit_i 					(hit_flag_reg 			),
	.done_o 				(replacement_done_flag 	), 		// logic high when replacement address generated
	.addr_o 				(replacement_ptr_bus 	) 		// replacement address generated
);


// cache controller
// ----------------------------------------------------------------------------------------------------------
localparam 	ST_NORMAL  				= 2'b00;
localparam 	ST_REQUEST_WRITEOUT 	= 2'b01;
localparam 	ST_REQUEST_READIN 		= 2'b10;
localparam 	ST_SERVICE_READIN 		= 2'b11;

reg [1:0]							state_reg;
reg [N_CAPACITY_BLOCKS-1:0]			dirtybit_reg;
reg 								request_wren_reg;
reg [BW_DATA_WORD-1:0] 				request_data_reg;

integer i;

always @(posedge clock_i) begin

	if (!resetn_i) begin

		// generics and control signals
		state_reg 					<= ST_NORMAL;
		stall_reg 					<= 1'b0;
		dirtybit_reg 				<= 'b0;

		// core / hart
		core_valid_reg 				<= 1'b0;
		core_data_mux_reg 			<= 1'b0; 		// out of reset default is to route from cache memory
		core_data_reg 				<= 'b0;

		// core request buffer
		read_request_buffer_reg 	<= 1'b0;
		request_wren_reg 			<= 1'b0;
		request_addr_reg 			<= 'b0;
		request_data_reg 			<= 'b0;

		// external buffers
		buffer_read_reg 			<= 1'b0;
		buffer_write_reg 			<= 1'b0;
		buffer_command_reg 			<= 'b0;
		buffer_address_reg 			<= 'b0;
		buffer_data_reg 			<= 'b0;

		// tag lookup table
		tag_memory_write_reg 		<= 1'b0;
		tag_memory_search_mux_reg 	<= 1'b0; 		// out of reset default is to route directly from core request
		tag_memory_tag_search_reg 	<= 'b0;
		tag_memory_tag_write_reg 	<= 'b0;
		tag_memory_addr_reg  		<= 'b0;

		// cache memory
		cache_memory_word_write_reg <= 1'b0;
		cache_memory_block_write_reg<= 1'b0;
		cache_memory_addr_reg  		<= 'b0;
		cache_memory_offset_reg  	<= 'b0;
		cache_memory_data_reg  		<= 'b0;

		// monitor
		hit_flag_reg 				<= 1'b0;
		miss_flag_reg 				<= 1'b0;
		writeback_flag_reg 			<= 1'b0;

	end
	else begin

		// default signals
		read_request_buffer_reg 		<= 1'b0; 	// core request buffer
		core_valid_reg 					<= 1'b0;
		buffer_read_reg 				<= 1'b0;
		buffer_write_reg 				<= 1'b0;
		tag_memory_write_reg 			<= 1'b0;
		tag_memory_search_mux_reg 		<= 1'b0; 	// default is to route from core
		cache_memory_word_write_reg 	<= 1'b0;
		cache_memory_block_write_reg 	<= 1'b0;
		hit_flag_reg 					<= 1'b0;
		miss_flag_reg 					<= 1'b0;
		writeback_flag_reg 				<= 1'b0;

		// cache controller sequencing control
		// -------------------------------------------------------------------------------------------
		case(state_reg)

			// nominal sequencing state - service requests that have propogated through tag lookup
			// ---------------------------------------------------------------------------------------
			ST_NORMAL: begin

				// register new request fields and manage hit/miss
				if (!empty_request_buffer) begin

					// pull from buffer
					read_request_buffer_reg 	<= 1'b1;
					request_wren_reg 			<= wren_request_buffer;
					request_addr_reg 			<= addr_request_buffer;
					request_data_reg 			<= data_request_buffer;
					cache_memory_offset_reg 	<= addr_request_buffer[BW_WORDS_PER_BLOCK-1:0];

					// hit
					// -------------------------
					if (cam_hit_i) begin
						hit_flag_reg 				<= 1'b1;
						core_data_mux_reg 			<= 1'b0;
						cache_memory_word_write_reg <= wren_request_buffer; 	// automatically set operation		
						cache_memory_addr_reg 		<= cam_cache_addr_search_i;	// cache address looked-up from cam
						tag_memory_search_mux_reg 	<= 1'b0; 					// only route from core if hit - 
																				// stall followup is routed from controller and may be another miss?
						// if load need to drive valid to latch
						if (!wren_request_buffer) begin
							core_valid_reg 			<= 1'b1;
						end
						// if store set the dirtybit
						else begin
							cache_memory_data_reg[31:0] 			<= data_request_buffer;
							dirtybit_reg[cam_cache_addr_search_i] 	<= 1'b1;
						end
					end

					// miss
					// -------------------------
					else begin
						cache_memory_addr_reg 		<= cam_cache_addr_search_i;	// cache address looked-up from cam
						miss_flag_reg 				<= 1'b1; 					// miss triggers replacement address generation
						stall_reg 					<= 1'b1; 					// stall the core/hart
						state_reg 					<= ST_REQUEST_READIN; 		// request the missed block on next state
					end

				end

			end

			// on miss request missed block and determine if writeout is necessary
			// ---------------------------------------------------------------------------------------
			ST_REQUEST_READIN: begin
				if (!buffer_full_i & replacement_done_flag) begin

					// send request to buffer
					buffer_write_reg 	<= 1'b1;
					buffer_command_reg 	<= `CACHE_REQUEST_READIN_BLOCK;
					buffer_address_reg 	<= request_addr_reg;

					// check the replacement address ptr to see if a writeout is required
					if (dirtybit_reg[replacement_ptr_bus]) begin

						// read the line to be replaced
						cache_memory_addr_reg 	<= replacement_ptr_bus;

						// drive lookup table to produce tag of address to writeout
						tag_memory_addr_reg 	<= replacement_ptr_bus;
						state_reg 				<= ST_REQUEST_WRITEOUT;

					end
					else begin
						state_reg 	<= ST_SERVICE_READIN;
					end
				end
			end


			// 
			// ---------------------------------------------------------------------------------------
			ST_REQUEST_WRITEOUT: begin
				if (!buffer_full_i) begin
					buffer_write_reg 	<= 1'b1;
					buffer_command_reg 	<= `CACHE_REQUEST_WRITEOUT_BLOCK;
					buffer_address_reg 	<= {cam_access_addr_search_i[BW_ACCESS_ADDR-1:BW_WORDS_PER_BLOCK],{BW_WORDS_PER_BLOCK{1'b0}}};
					buffer_data_reg 	<= cache_memory_block_i;
					state_reg 			<= ST_SERVICE_READIN;
					dirtybit_reg[replacement_ptr_bus] 	<= 1'b0;
				end
			end


			// 
			// ---------------------------------------------------------------------------------------
			ST_SERVICE_READIN: begin
				if (!buffer_empty_i) begin

					// pull from buffer and write to cache memory
					buffer_read_reg 				<= 1'b1;
					cache_memory_block_write_reg 	<= 1'b1;
					cache_memory_addr_reg 			<= replacement_ptr_bus;

					// if load operation then just write the imported block to memory
					// load requires a route to core / hart
					if (!request_wren_reg) begin 								
						cache_memory_data_reg 		<= buffer_data_i;

						// set route path
						core_valid_reg 				<= 1'b1;
						core_data_mux_reg 			<= 1'b1; 

						for (i = 0; i < N_WORDS_PER_BLOCK; i = i + 1) begin
							if (cache_memory_offset_reg == i) begin
								core_data_reg 	<= buffer_data_i[(BW_DATA_WORD*i)+:BW_DATA_WORD];
							end
						end
					end 
					// if store operation then just concurrently overwrite the target word
					// of the block while writing it to memory
					else begin 					

						cache_memory_data_reg <= buffer_data_i;				

						for (i = 0; i < N_WORDS_PER_BLOCK; i = i + 1) begin
							if (cache_memory_offset_reg == i) begin
								cache_memory_data_reg[(BW_DATA_WORD*i)+:BW_DATA_WORD] 	<= request_data_reg;
							end
						end

						dirtybit_reg[replacement_ptr_bus] 	<= 1'b1;

					end

					// write new block to the lookup table
					tag_memory_write_reg 			<= 1'b1;
					tag_memory_tag_write_reg 		<= request_addr_reg; 		// access_addr to write
					tag_memory_addr_reg 			<= replacement_ptr_bus; 	// where to write ^

					// if there is an additional request in the buffer route it through
					// the lookup table, do not rotate buffer until next state
					state_reg 						<= ST_NORMAL;
					stall_reg 						<= 1'b0;
					if (!empty_request_buffer) begin
						tag_memory_search_mux_reg 	<= 1'b1;
						tag_memory_tag_search_reg 	<= addr_request_buffer;
					end
				end
			end

		endcase
	end
end

endmodule

`endif