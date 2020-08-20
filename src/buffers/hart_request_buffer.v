`ifndef _HART_REQUEST_BUFFER_V_
`define _HART_REQUEST_BUFFER_V_

module hart_request_buffer #(
	parameter N_ENTRIES = 0,
	parameter BW_ADDR 	= 0,
	parameter BW_DATA 	= 0
)(
	input 					clock_i,
	input 					resetn_i,
	input 					wren_i,
	input 	[BW_ADDR-1:0] 	addr_i,
	input 	[BW_DATA-1:0]	data_i,
	input 					write_i,
	output 					full_o,
	output 					wren_o,
	output 	[BW_ADDR-1:0] 	addr_o,
	output 	[BW_DATA-1:0]	data_o,
	input 					read_i,
	output 					empty_o
);

// parameterizations
// ----------------------------------------------------------
localparam BW_ENTRIES = `CLOG2(N_ENTRIES);


// buffer logic
// ----------------------------------------------------------
reg [N_ENTRIES-1:0]		wren_buffer;
reg [BW_ADDR-1:0]		addr_buffer	[0:N_ENTRIES-1];
reg [BW_DATA-1:0]		data_buffer	[0:N_ENTRIES-1];

reg [BW_ENTRIES-1:0]	write_ptr_reg,
						read_ptr_reg;
reg [BW_ENTRIES:0]		count_reg;

assign full_o 	= (count_reg == N_ENTRIES) 	? 1'b1 : 1'b0; 
assign empty_o 	= (count_reg == 'b0) 		? 1'b1 : 1'b0;
assign wren_o 	= wren_buffer[read_ptr_reg];
assign addr_o 	= addr_buffer[read_ptr_reg];
assign data_o 	= data_buffer[read_ptr_reg];

integer i;
always @(posedge clock_i) begin
	if (!resetn_i) begin
		write_ptr_reg 	<= 'b0;
		read_ptr_reg 	<= 'b0;
		count_reg 		<= 'b0;
		wren_buffer 	<= 'b0;
		for (i = 0; i < N_ENTRIES; i = i + 1) begin
			addr_buffer[i] <= 'b0;
			data_buffer[i] <= 'b0;
		end
	end
	else begin
		if ((read_i & !empty_o) & (write_i & !full_o)) begin
			read_ptr_reg 				<= read_ptr_reg + 1'b1;
			write_ptr_reg 				<= write_ptr_reg + 1'b1;
			wren_buffer[write_ptr_reg] 	<= wren_i;
			addr_buffer[write_ptr_reg] 	<= addr_i;
			data_buffer[write_ptr_reg] 	<= data_i;
		end
		else if ((read_i & !empty_o) & !write_i) begin
			read_ptr_reg 				<= read_ptr_reg + 1'b1;
			count_reg 					<= count_reg - 1'b1;
		end
		else if (!read_i & (write_i & !full_o)) begin
			write_ptr_reg 				<= write_ptr_reg + 1'b1;
			wren_buffer[write_ptr_reg] 	<= wren_i;
			addr_buffer[write_ptr_reg] 	<= addr_i;
			data_buffer[write_ptr_reg] 	<= data_i;
			count_reg 					<= count_reg + 1'b1;
		end
	end
end

endmodule

`endif