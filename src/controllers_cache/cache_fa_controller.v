`ifndef _CACHE_FA_CONTROLLER_V_
`define _CACHE_FA_CONTROLLER_V_

module cache_fa_controller #(
	parameter BW_CORE_ADDR_BYTE		= 32, 				// byte addressible input address
	parameter BW_USED_ADDR_WORD 	= 24, 				// byte addressible converted address
	parameter BW_DATA_WORD 			= 32,  				// bits in a data word
	parameter BW_DATA_EXTERNAL_BUS 	= 512, 				// bits that can be transfered between this level cache and next
	parameter BW_CACHE_COMMAND 		= 3,
	parameter CACHE_WORDS_PER_BLOCK = 16, 				// words in a block
	parameter CACHE_CAPACITY_BLOCKS = 128, 				// cache capacity in blocks
	parameter CACHE_ASSOCIATIVITY 	= 0,
	parameter CACHE_POLICY 			= "",
	parameter CACHE_INIT_STALL 		= 0

	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_WORDS_PER_BLOCK 	= `CLOG2(CACHE_WORDS_PER_BLOCK),
	parameter BW_CACHE_ADDR 		= `CLOG2(CACHE_CAPACITY_BLOCKS),
	parameter BW_ADDR_TAG 			= BW_USED_ADDR_WORD - BW_WORDS_PER_BLOCK
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
	input 	[BW_CORE_ADDR_BYTE-1:0]		core_addr_i,
	input 	[BW_DATA_WORD-1:0] 			core_data_i,
	output 								core_valid_o,
	output 	[BW_DATA_WORD-1:0] 			core_data_o,

	// incoming buffer
	output 								buffer_read_o,
	input 								buffer_empty_i,
	input 	[BW_CACHE_COMMAND-1:0]		buffer_command_i,
	input 	[BW_USED_ADDR_WORD-1:0] 	buffer_address_i,
	input 	[BW_DATA_EXTERNAL_BUS-1:0] 	buffer_data_i,

	// outgoing buffer
	output 								buffer_write_o,
	input 								buffer_full_i,
	output 	[BW_CACHE_COMMAND-1:0]		buffer_command_o,
	output 	[BW_USED_ADDR_WORD-1:0]		buffer_address_o,
	output 	[BW_DATA_EXTERNAL_BUS-1:0]	buffer_data_o,

	// tag lookup table
	input 								tag_memory_hit_i,
	output 								tag_memory_write_o,
	output 	[BW_ADDR_TAG-1:0]			tag_memory_tag_search_o,
	output 	[BW_ADDR_TAG-1:0]			tag_memory_tag_write_o,
	output 	[BW_CACHE_ADDR-1:0] 		tag_memory_addr_o,
	input 	[BW_CACHE_ADDR-1:0] 		tag_memory_addr_i,
	input 	[BW_ADDR_TAG-1:0] 	 		tag_memory_tag_i,

	// cache memory 
	output 								cache_memory_word_write_o,
	output 								cache_memory_block_write_o,
	output 	[BW_CACHE_ADDR-1:0]			cache_memory_addr_o,
	output 	[BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_o,
	output 	[BW_DATA_EXTERNAL_BUS-1:0] 	cache_memory_data_o,
	input 	[BW_DATA_WORD-1:0] 			cache_memory_word_i,
	input 	[BW_DATA_EXTERNAL_BUS-1:0] 	cache_memory_block_i,

	// metric monitor
	output [4:0] 						flag_o

);

// parameterization
// ----------------------------------------------------------------------------------------------------------
`ifndef SIMULATION_SYNTHESIS
localparam BW_WORDS_PER_BLOCK 	= `CLOG2(CACHE_WORDS_PER_BLOCK);
localparam BW_CACHE_ADDR 		= `CLOG2(CACHE_CAPACITY_BLOCKS);
localparam BW_ADDR_TAG 			= BW_USED_ADDR_WORD - BW_WORDS_PER_BLOCK;
`endif

// core request buffer
// ----------------------------------------------------------------------------------------------------------
wire 	[BW_USED_ADDR_WORD-1:0] core_addr_bus;
wire 							wren_request_buffer;
wire 	[BW_USED_ADDR_WORD-1:0]	addr_request_buffer;
wire 	[BW_DATA_WORD-1:0] 		data_request_buffer;
wire 							empty_request_buffer;
reg 							read_request_buffer_reg;
wire 	[BW_ADDR_TAG-1:0] 		tag_request_buffer;

assign core_addr_bus = core_addr_i[BW_USED_ADDR_WORD+1:2]; 	// core address is 32b, byte addressible
															// store address as 24b, word addressible
assign tag_request_buffer = addr_request_buffer[BW_USED_ADDR_WORD-1:BW_WORDS_PER_BLOCK];

hart_request_buffer #(
	.N_ENTRIES		(4 							),
	.BW_ADDR 		(BW_USED_ADDR_WORD 			),
	.BW_DATA 		(BW_DATA_WORD 				)
) request_buffer_inst (
	.clock_i 		(clock_rw_i 				),
	.resetn_i 		(resetn_i 					),
	.wren_i 		(core_wren_i 				),
	.addr_i 		(core_addr_bus 				),
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
wire 	[BW_ADDR_TAG-1:0]			core_tag_bus; 			// block tag from current core request
reg 								core_valid_reg;
reg 								core_data_mux_reg;
reg 	[BW_DATA_WORD-1:0] 			core_data_reg;

assign core_tag_bus 	= core_addr_bus[BW_USED_ADDR_WORD-1:BW_WORDS_PER_BLOCK];
assign core_valid_o 	= core_valid_reg;
assign core_data_o 		= (!core_data_mux_reg) ? cache_memory_word_i : core_data_reg;

// buffer signals
// -----------------------------
reg 								buffer_read_reg;
reg 								buffer_write_reg;
reg 	[BW_CACHE_COMMAND-1:0]		buffer_command_reg;
reg 	[BW_USED_ADDR_WORD-1:0]		buffer_address_reg;
reg 	[BW_DATA_EXTERNAL_BUS-1:0]	buffer_data_reg;

assign buffer_read_o 	= buffer_read_reg;
assign buffer_write_o 	= buffer_write_reg;
assign buffer_command_o = buffer_command_reg;
assign buffer_address_o = buffer_address_reg;
assign buffer_data_o 	= buffer_data_reg;

// tag lookup table
// -----------------------------
reg 								tag_memory_write_reg;
reg 								tag_memory_search_mux_reg;
reg 	[BW_ADDR_TAG-1:0]			tag_memory_tag_search_reg,
									tag_memory_tag_write_reg;
reg 	[BW_CACHE_ADDR-1:0] 		tag_memory_addr_reg;

assign tag_memory_write_o 		= tag_memory_write_reg;
assign tag_memory_tag_write_o 	= tag_memory_tag_write_reg;
assign tag_memory_addr_o 		= tag_memory_addr_reg;
assign tag_memory_tag_search_o 	= (!tag_memory_search_mux_reg) ? core_tag_bus : tag_memory_tag_search_reg;

// cache memory
// -----------------------------
reg 								cache_memory_word_write_reg;
reg 								cache_memory_block_write_reg;
reg 	[BW_CACHE_ADDR-1:0]			cache_memory_addr_reg;
reg 	[BW_WORDS_PER_BLOCK-1:0] 	cache_memory_offset_reg;
reg 	[BW_DATA_EXTERNAL_BUS-1:0] 	cache_memory_data_reg;

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

assign flag_o = {hit_flag_reg, miss_flag_reg, writeback_flag_reg, 2'b00};


// policy controller
// ----------------------------------------------------------------------------------------------------------
wire 						replacement_done_flag;
wire [BW_CACHE_ADDR-1:0] 	replacement_ptr_bus;

set_cache_fifo_policy_controller #(
	.CACHE_BLOCK_CAPACITY 	(CACHE_CAPACITY_BLOCKS	)
) cache_policy_controller_inst (
	.clock_i 				(clock_rw_i 			),
	.resetn_i 				(resetn_i 				),
	.miss_i 				(miss_flag_reg 			), 		// pulse trigger to generate a replacement address
	.done_o 				(replacement_done_flag 	), 		// logic high when replacement address generated
	.addr_o 				(replacement_ptr_bus 	) 		// replacement address generated
);


// cache controller
// ----------------------------------------------------------------------------------------------------------
localparam 	ST_NORMAL  				= 3'b000;
localparam 	ST_REQUEST_WRITEOUT 	= 3'b001;
localparam 	ST_REQUEST_READIN 		= 3'b010;
localparam 	ST_SERVICE_READIN 		= 3'b011;


reg [2:0]							state_reg;
reg [CACHE_CAPACITY_BLOCKS-1:0]		dirtybit_reg;
reg 								request_wren_reg;
reg [BW_USED_ADDR_WORD-1:0]			request_addr_reg;
reg [BW_DATA_WORD-1:0] 				request_data_reg;


always @(posedge clock_i) begin

	if (!resetn_i) begin

		// generics and control signals
		state_reg 					<= ST_NORMAL;
		stall_reg 					<= CACHE_INIT_STALL;
		dirtybit_reg 				<= 'b0;

		// core / hart
		core_valid_reg 				<= 1'b0;
		core_data_mux_reg 			<= 1'b0; 		// out of reset default is to route from cache memory
		core_data_reg 				<= 'b0;

		// core request buffer
		read_request_buffer_reg 	<= 1'b0;

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
		cache_memory_word_write_reg 	<= 1'b0;
		cache_memory_block_write_reg 	<= 1'b0;
		cache_memory_addr_reg  			<= 'b0;
		cache_memory_offset_reg  		<= 'b0;
		cache_memory_data_reg  			<= 'b0;

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
					tag_memory_tag_search_reg 	<= tag_request_buffer;

					// hit
					// -------------------------
					if (tag_memory_hit_i) begin
						hit_flag_reg 				<= 1'b1;
						core_data_mux_reg 			<= 1'b0;
						cache_memory_word_write_reg <= wren_request_buffer; 	// automatically set operation
						cache_memory_addr_reg 		<= tag_memory_addr_i; 		// cache address looked-up from cam
						tag_memory_search_mux_reg 	<= 1'b0; 					// only route from core if hit - 
																				// stall followup is routed from controller and may be another miss?
						// if load need to drive valid to latch
						if (!wren_request_buffer) begin
							core_valid_reg 			<= 1'b1;
						end
						// if store set the dirtybit
						else begin
							//cache_memory_word_write_reg 		<= 1'b1;
							cache_memory_data_reg[31:0] 		<= data_request_buffer;
							dirtybit_reg[tag_memory_addr_i] 	<= 1'b1;
						end
					end

					// miss
					// -------------------------
					else begin
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
					//buffer_address_reg 	<= {tag_memory_tag_i, word_offset_reg};
					buffer_address_reg 	<= {tag_memory_tag_i, 4'b0000};
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

						case(cache_memory_offset_reg)
							4'b0000: core_data_reg <= buffer_data_i[31:0];
							4'b0001: core_data_reg <= buffer_data_i[63:32];
							4'b0010: core_data_reg <= buffer_data_i[95:64];
							4'b0011: core_data_reg <= buffer_data_i[127:96];
							4'b0100: core_data_reg <= buffer_data_i[159:128];
							4'b0101: core_data_reg <= buffer_data_i[191:160];
							4'b0110: core_data_reg <= buffer_data_i[223:192];
							4'b0111: core_data_reg <= buffer_data_i[255:224];
							4'b1000: core_data_reg <= buffer_data_i[287:256];
							4'b1001: core_data_reg <= buffer_data_i[319:288];
							4'b1010: core_data_reg <= buffer_data_i[351:320];
							4'b1011: core_data_reg <= buffer_data_i[383:352];
							4'b1100: core_data_reg <= buffer_data_i[415:384];
							4'b1101: core_data_reg <= buffer_data_i[447:416];
							4'b1110: core_data_reg <= buffer_data_i[479:448];
							4'b1111: core_data_reg <= buffer_data_i[511:480];
						endcase
						//core_data_reg 				<= buffer_data_i[31+32*cache_memory_offset_reg:32*cache_memory_offset_reg];

					end 
					// if store operation then just concurrently overwrite the target word
					// of the block while writing it to memory
					else begin 												
						//cache_memory_data_reg 		<= buffer_data_i & (request_data_reg << 32*cache_memory_offset_reg);
						//cache_memory_data_reg 		<= buffer_data_i;// & (request_data_reg << 32*cache_memory_offset_reg);

						case(cache_memory_offset_reg)
							4'b0000: cache_memory_data_reg <= {buffer_data_i[511:32],request_data_reg};
							4'b0001: cache_memory_data_reg <= {buffer_data_i[511:64],request_data_reg,buffer_data_i[31:0]};
							4'b0010: cache_memory_data_reg <= {buffer_data_i[511:96],request_data_reg,buffer_data_i[63:0]};
							4'b0011: cache_memory_data_reg <= {buffer_data_i[511:128],request_data_reg,buffer_data_i[95:0]};
							4'b0100: cache_memory_data_reg <= {buffer_data_i[511:160],request_data_reg,buffer_data_i[127:0]};
							4'b0101: cache_memory_data_reg <= {buffer_data_i[511:192],request_data_reg,buffer_data_i[159:0]};
							4'b0110: cache_memory_data_reg <= {buffer_data_i[511:224],request_data_reg,buffer_data_i[191:0]};
							4'b0111: cache_memory_data_reg <= {buffer_data_i[511:256],request_data_reg,buffer_data_i[223:0]};
							4'b1000: cache_memory_data_reg <= {buffer_data_i[511:288],request_data_reg,buffer_data_i[255:0]};
							4'b1001: cache_memory_data_reg <= {buffer_data_i[511:320],request_data_reg,buffer_data_i[287:0]};
							4'b1010: cache_memory_data_reg <= {buffer_data_i[511:352],request_data_reg,buffer_data_i[319:0]};
							4'b1011: cache_memory_data_reg <= {buffer_data_i[511:384],request_data_reg,buffer_data_i[351:0]};
							4'b1100: cache_memory_data_reg <= {buffer_data_i[511:416],request_data_reg,buffer_data_i[383:0]};
							4'b1101: cache_memory_data_reg <= {buffer_data_i[511:448],request_data_reg,buffer_data_i[415:0]};
							4'b1110: cache_memory_data_reg <= {buffer_data_i[511:480],request_data_reg,buffer_data_i[447:0]};
							4'b1111: cache_memory_data_reg <= {request_data_reg,buffer_data_i[479:0]};

							//4'b0100: cache_memory_data_reg <= {buffer_data_i[511:32],request_data_reg};

						endcase

						//cache_memory_word_write_reg 		<= 1'b1;
						//cache_memory_data_reg[31:0] 		<= data_request_buffer;
						dirtybit_reg[replacement_ptr_bus] 	<= 1'b1;

					end

					// write new block to the lookup table
					tag_memory_write_reg 			<= 1'b1;
					tag_memory_tag_write_reg 		<= tag_memory_tag_search_reg;
					tag_memory_addr_reg 			<= replacement_ptr_bus;

					// if there is an additional request in the buffer route it through
					// the lookup table, do not rotate buffer until next state
					state_reg 						<= ST_NORMAL;
					stall_reg 						<= 1'b0;
					if (!empty_request_buffer) begin
						tag_memory_search_mux_reg 	<= 1'b1;
						tag_memory_tag_search_reg 	<= tag_request_buffer;
					end
				end
			end

		endcase
	end
end

endmodule

`endif