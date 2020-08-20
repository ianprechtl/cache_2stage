`ifndef _TEST_MEMORY_CONTROLLER_V_
`define _TEST_MEMORY_CONTROLLER_V_

module test_memory_controller #(
	parameter BW_RAM_ADDR_WORD 		= 17,
	parameter BW_USED_ADDR_BYTE 	= 26, 				// byte addressible converted address
	parameter BW_DATA_WORD 			= 32,  				// bits in a data word
	parameter BW_DATA_EXTERNAL_BUS 	= 512, 				// bits that can be transfered between this level cache and next
	parameter BW_CACHE_COMMAND 		= 3,
	parameter CACHE_WORDS_PER_BLOCK = 16, 				// words in a block
	parameter CACHE_CAPACITY_BLOCKS = 128, 				// cache capacity in blocks
	parameter CACHE_ASSOCIATIVITY 	= 0, 					
	parameter CACHE_POLICY 			= "",
	parameter BW_CONFIG_REGS 		= 32,
	parameter BW_USED_ADDR_WORD 	= BW_USED_ADDR_BYTE - 2,
	parameter BW_WORDS_PER_BLOCK 	= `CLOG2(CACHE_WORDS_PER_BLOCK)
)(

	// generics
	input 								clock_i,
	input 								clock_rw_i,
	input 								resetn_i,

	// instruction cache
	// ---------------------------------------------------------

	// to previous level (level 1)
	output 								external_write_o,
	output 	[BW_CACHE_COMMAND-1:0] 		external_command_o,
	output 	[BW_USED_ADDR_WORD-1:0] 	external_addr_o,
	output  [BW_DATA_EXTERNAL_BUS-1:0] 	external_data_o,
	input  								external_full_i,

	// from previous level (level 1)
	input 								external_write_i,
	input  	[BW_CACHE_COMMAND-1:0] 		external_command_i,
	input 	[BW_USED_ADDR_WORD-1:0] 	external_addr_i,
	input  	[BW_DATA_EXTERNAL_BUS-1:0] 	external_data_i,
	output 								external_full_o,

	// main memory									
	output 								main_wren_o,
	output 	[BW_RAM_ADDR_WORD-1:0] 		main_addr_o,
	output 	[BW_DATA_WORD-1:0] 			main_data_o,
	input  	[BW_DATA_WORD-1:0] 			main_data_i

);


// previous level buffer
// -------------------------------------------------------------------------------------------------
reg 								buffer_read_flag_reg;
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
	.write_i 				(external_write_i 			), 	// to first level cache	
	.command_i 				(external_command_i 		),
	.addr_i  				(external_addr_i 			),
	.data_i  				(external_data_i 			),
	.full_o  				(external_full_o 			),
	.read_i  				(buffer_read_flag_reg 		),	// from first level cache
	.empty_o  				(buffer_empty_flag 			),
	.command_o  			(buffer_command_bus 		),
	.addr_o  				(buffer_address_bus 		),
	.data_o  				(buffer_data_bus 			)
);

reg 								external_write_reg;
reg 	[BW_CACHE_COMMAND-1:0] 		external_command_reg;
reg 	[BW_USED_ADDR_WORD-1:0] 	external_addr_reg;
reg  	[BW_DATA_EXTERNAL_BUS-1:0] 	external_data_reg;

assign external_write_o 	= external_write_reg;
assign external_command_o 	= external_command_reg;
assign external_addr_o 		= external_addr_reg;
assign external_data_o 		= external_data_reg;


// main memory signals
// -------------------------------------------------------------------------------------------------
reg 								main_wren_reg;
reg 	[BW_RAM_ADDR_WORD-1:0] 		main_addr_reg;
reg 	[BW_DATA_WORD-1:0] 			main_data_reg;

assign main_wren_o = main_wren_reg;
assign main_addr_o = main_addr_reg;
assign main_data_o = main_data_reg;


// controller
// -------------------------------------------------------------------------------------------------
localparam ST_NORMAL 				= 2'b00;
localparam ST_READ_MAIN_MEMORY 		= 2'b01;
localparam ST_WRITE_MAIN_MEMORY 	= 2'b10;
localparam ST_TRANSFER_BLOCK_TO_L1 	= 2'b11;

reg [1:0]						state_reg;
reg [BW_WORDS_PER_BLOCK-1:0] 	n_transfer_reg;

reg [BW_CACHE_COMMAND-1:0] 		buffer_command_reg;
reg [BW_USED_ADDR_WORD-1:0] 	buffer_address_reg;
reg [BW_DATA_EXTERNAL_BUS-1:0] 	buffer_data_reg;

always @(posedge clock_i) begin
	if (!resetn_i) begin
		main_wren_reg 			<= 1'b0;
		main_addr_reg 			<= 'b0;
		main_data_reg 			<= 'b0;
		external_write_reg 		<= 1'b0;
		external_command_reg 	<= 'b0;
		external_addr_reg 		<= 'b0;
		external_data_reg 		<= 'b0;
		n_transfer_reg			<= 'b0;
		state_reg 				<= ST_NORMAL;
		buffer_command_reg 		<= 'b0;
		buffer_address_reg 		<= 'b0;
		buffer_data_reg 		<= 'b0;
		buffer_read_flag_reg 	<= 1'b0;
	end
	else begin

		// default signals
		main_wren_reg 			<= 1'b0;
		external_write_reg 		<= 1'b0;
		buffer_read_flag_reg 	<= 1'b0;

		case(state_reg)

			ST_NORMAL: begin

				// look at buffer to see if there is a request that needs to be seviced
				if (!buffer_empty_flag) begin
					buffer_read_flag_reg 	<= 1'b1;
					buffer_command_reg 		<= buffer_command_bus;
					buffer_address_reg 		<= buffer_address_bus;
					buffer_data_reg 		<= buffer_data_bus;

					if (buffer_command_bus == `CACHE_REQUEST_READIN_BLOCK) begin
						n_transfer_reg 	<= 'b0;
						state_reg 		<= ST_READ_MAIN_MEMORY;
						main_addr_reg 	<= {buffer_address_bus[BW_RAM_ADDR_WORD-1:4],4'b0000};
					end
					else if (buffer_command_bus == `CACHE_REQUEST_WRITEOUT_BLOCK) begin
						n_transfer_reg 	<= 'b1;

						// write to address
						main_wren_reg 	<= 1'b1;
						main_addr_reg 	<= {buffer_address_bus[BW_RAM_ADDR_WORD-1:4],4'b0000};
						main_data_reg 	<= buffer_data_bus[31:0];

						state_reg 		<= ST_WRITE_MAIN_MEMORY;
					end
				end
			end

			ST_READ_MAIN_MEMORY: begin
				// store block into temporary register
				//buffer_data_reg[31+32*n_transfer_reg:32*n_transfer_reg] <= main_data_i;

				case(n_transfer_reg)
					4'b0000: buffer_data_reg[31:0] 	<= main_data_i;
					4'b0001: buffer_data_reg[63:32] <= main_data_i;
					4'b0010: buffer_data_reg[95:64] <= main_data_i;
					4'b0011: buffer_data_reg[127:96] <= main_data_i;
					4'b0100: buffer_data_reg[159:128] <= main_data_i;
					4'b0101: buffer_data_reg[191:160] <= main_data_i;
					4'b0110: buffer_data_reg[223:192] <= main_data_i;
					4'b0111: buffer_data_reg[255:224] <= main_data_i;
					4'b1000: buffer_data_reg[287:256] <= main_data_i;
					4'b1001: buffer_data_reg[319:288] <= main_data_i;
					4'b1010: buffer_data_reg[351:320] <= main_data_i;
					4'b1011: buffer_data_reg[383:352] <= main_data_i;
					4'b1100: buffer_data_reg[415:384] <= main_data_i;
					4'b1101: buffer_data_reg[447:416] <= main_data_i;
					4'b1110: buffer_data_reg[479:448] <= main_data_i;
					4'b1111: buffer_data_reg[511:480] <= main_data_i;
				endcase

				if (n_transfer_reg == 4'b1111) begin
					state_reg 		<= ST_TRANSFER_BLOCK_TO_L1;
				end
				else begin
					main_addr_reg 	<= main_addr_reg + 1'b1;
					n_transfer_reg 	<= n_transfer_reg + 1'b1;
				end
			end

			ST_WRITE_MAIN_MEMORY: begin

				// write next word of block
				main_wren_reg 	<= 1'b1;
				main_addr_reg 	<= main_addr_reg + 1'b1;

				case(n_transfer_reg)
					4'b0000: main_data_reg 	<= buffer_data_reg[31:0];
					4'b0001: main_data_reg 	<= buffer_data_reg[63:32];
					4'b0010: main_data_reg 	<= buffer_data_reg[95:64];
					4'b0011: main_data_reg 	<= buffer_data_reg[127:96];
					4'b0100: main_data_reg 	<= buffer_data_reg[159:128];
					4'b0101: main_data_reg 	<= buffer_data_reg[191:160];
					4'b0110: main_data_reg 	<= buffer_data_reg[223:192];
					4'b0111: main_data_reg 	<= buffer_data_reg[255:224];
					4'b1000: main_data_reg 	<= buffer_data_reg[287:256];
					4'b1001: main_data_reg 	<= buffer_data_reg[319:288];
					4'b1010: main_data_reg 	<= buffer_data_reg[351:320];
					4'b1011: main_data_reg 	<= buffer_data_reg[383:352];
					4'b1100: main_data_reg 	<= buffer_data_reg[415:384];
					4'b1101: main_data_reg 	<= buffer_data_reg[447:416];
					4'b1110: main_data_reg 	<= buffer_data_reg[479:448];
					4'b1111: main_data_reg 	<= buffer_data_reg[511:480];
				endcase

				if (n_transfer_reg == 4'b1111) state_reg 		<= ST_NORMAL;
				else n_transfer_reg <= n_transfer_reg + 1'b1;
						

			end

			ST_TRANSFER_BLOCK_TO_L1: begin
				if (!external_full_o) begin
					external_write_reg 		<= 1'b1;
					external_addr_reg 		<= buffer_address_reg;
					external_command_reg 	<= `CACHE_SERVICE_READIN_BLOCK;
					external_data_reg 		<= buffer_data_reg;
					state_reg 				<= ST_NORMAL;
				end
			end

		endcase
	end
end

endmodule

`endif