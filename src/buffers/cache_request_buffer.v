// commands:
// 000: word read 	(read in)
// 001: word write 	(write out)
// 010: block read 	(read in)
// 011: block write (write out)
// if leading bit -> do not cache just service

`ifndef _CACHE_REQUEST_BUFFER_V_
`define _CACHE_REQUEST_BUFFER_V_

module cache_request_buffer #(
	parameter N_ENTRIES 	= 0, 		// size of the buffer
	parameter BW_COMMAND 	= 0,  		// size of the command to register
	parameter BW_ADDR 		= 0, 		// size of the address to register
	parameter BW_DATA 		= 0 		// size of entire cache line
)(
	input 						clock_i,
	input 						resetn_i,

	// lower level memory
	input 						write_i,
	input 	[BW_COMMAND-1:0]	command_i,
	input 	[BW_ADDR-1:0] 		addr_i,
	input 	[BW_DATA-1:0] 		data_i,
	output 						full_o,

	// higher level memory
	input 						read_i,
	output  					empty_o,
	output 	[BW_COMMAND-1:0]	command_o,
	output 	[BW_ADDR-1:0] 		addr_o,
	output 	[BW_DATA-1:0] 		data_o

);

// parameterizations
// ------------------------------------------------------------------------------------
localparam BW_ENTRIES = `CLOG2(N_ENTRIES);


// internal signals
// ------------------------------------------------------------------------------------
reg 	[BW_COMMAND-1:0]	command_buffer	[0:N_ENTRIES-1];
reg 	[BW_ADDR-1:0]		address_buffer	[0:N_ENTRIES-1];
reg 	[BW_DATA-1:0]		data_buffer		[0:N_ENTRIES-1];

reg 	[BW_ENTRIES:0] 		active_entries_reg;
reg 	[BW_ENTRIES-1:0]	read_ptr_reg,
							write_ptr_reg;

assign full_o 		= (active_entries_reg == N_ENTRIES) ? 1'b1 : 1'b0;
assign empty_o 		= (active_entries_reg == 'b0) 		? 1'b1 : 1'b0;
assign command_o 	= command_buffer[read_ptr_reg];
assign addr_o 		= address_buffer[read_ptr_reg];
assign data_o 		= data_buffer[read_ptr_reg];

integer i;
always @(posedge clock_i) begin
	if (!resetn_i) begin

		active_entries_reg 	<= 'b0;
		read_ptr_reg 		<= 'b0;
		write_ptr_reg 		<= 'b0;

		for (i = 0; i < N_ENTRIES; i = i + 1) begin
			command_buffer[i] 	<= 'b0;
			address_buffer[i]	<= 'b0;
			data_buffer[i] 		<= 'b0;
		end

	end
	else begin

		if ((read_i & !empty_o) & (write_i & !full_o)) begin

			command_buffer[write_ptr_reg] 	<= command_i;
			address_buffer[write_ptr_reg] 	<= addr_i;
			data_buffer[write_ptr_reg] 		<= data_i;

			read_ptr_reg 	<= read_ptr_reg + 1'b1;
			write_ptr_reg	<= write_ptr_reg + 1'b1;
		end

		else if (read_i & !empty_o) begin
			read_ptr_reg 					<= read_ptr_reg + 1'b1;
			active_entries_reg 				<= active_entries_reg - 1'b1;
		end

		else if (write_i & !full_o) begin
			command_buffer[write_ptr_reg] 	<= command_i;
			address_buffer[write_ptr_reg] 	<= addr_i;
			data_buffer[write_ptr_reg] 		<= data_i;

			write_ptr_reg					<= write_ptr_reg + 1'b1;
			active_entries_reg 				<= active_entries_reg + 1'b1;
		end

	end
end

endmodule

`endif