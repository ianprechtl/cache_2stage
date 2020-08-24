`ifndef _CACHE_POLICY_CONTROLLER_FIFO_V_
`define _CACHE_POLICY_CONTROLLER_FIFO_V_

module cache_policy_controller_fifo #(
	// port parameters
	parameter BW_ACCESS_ADDR 	= 0,
	// design parameters
	parameter N_CAPACITY_BLOCKS = 0,
	parameter N_WORDS_PER_BLOCK = 0,
	parameter ASSOCIATIVITY 	= 0	
	// derived parameters
	`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_CAPACITY_BLOCKS = `CLOG2(N_CAPACITY_BLOCKS)
	`endif
)(
	input 								clock_i,
	input 								resetn_i,
	input 	[BW_ACCESS_ADDR-1:0] 		access_addr_i,
	input 	[BW_CAPACITY_BLOCKS-1:0] 	cache_addr_i, 	// req. address to update policy
 	input 								miss_i, 		// pulse trigger to generate a replacement address
	input 								hit_i, 			// pulse trigger to update policy
	output 								done_o, 		// logic high when replacement address generated
	output 	[BW_CAPACITY_BLOCKS-1:0] 	addr_o  		// replacement address generated
);

// parameterization
// ----------------------------------------------------------------------------------------------------------
localparam BW_FIFO 	= `CLOG2(ASSOCIATIVITY);
localparam N_FIFO 	= N_CAPACITY_BLOCKS / ASSOCIATIVITY;
localparam BW_WORDS_PER_BLOCK = `CLOG2(N_WORDS_PER_BLOCK);
`ifndef SIMULATION_SYNTHESIS
localparam BW_CAPACITY_BLOCKS = `CLOG2(N_CAPACITY_BLOCKS);
`endif

// policy controller
// ----------------------------------------------------------------------------------------------------------
reg 							done_reg;
reg [BW_CAPACITY_BLOCKS-1:0] 	addr_reg;

assign done_o = done_reg;
assign addr_o = addr_reg;

generate
	
	// FULLY ASSOCIATIVE
	// ------------------------------------------------------------------------------------------------------
	if (ASSOCIATIVITY == N_CAPACITY_BLOCKS) begin

		reg [BW_FIFO-1:0]				fifo_counter_regs;

		always @(posedge clock_i) begin
			// reset state
			if(!resetn_i) begin
				done_reg 			<= 1'b0;
				addr_reg 			<= 'b0;
				fifo_counter_regs 	<= 'b0;
			end
			// active sequencing state
			else begin
				if (miss_i) begin
					addr_reg 			<= fifo_counter_regs;
					done_reg 			<= 1'b1;
					fifo_counter_regs 	<= fifo_counter_regs + 1'b1;
				end
			end
		end
	end

	// SET ASSOCIATIVE
	// ------------------------------------------------------------------------------------------------------
	else begin

		reg [BW_FIFO-1:0]				fifo_counter_regs	[0:N_FIFO-1];

		integer i;

		localparam BW_N_FIFO = `CLOG2(N_FIFO);

		wire [BW_N_FIFO-1:0] access_grp_bus = access_addr_i[BW_WORDS_PER_BLOCK+:BW_N_FIFO];

		always @(posedge clock_i) begin
			// reset state
			if(!resetn_i) begin
				done_reg 			<= 1'b0;
				addr_reg 			<= 'b0;
				for (i = 0; i < N_FIFO; i = i + 1) fifo_counter_regs[i] <= 'b0;
			end
			// active sequencing state
			else begin
				if (miss_i) begin
					addr_reg 			<= {
											fifo_counter_regs[access_grp_bus],
											access_grp_bus
											};
					done_reg 			<= 1'b1;

					fifo_counter_regs[access_grp_bus] <= fifo_counter_regs[access_grp_bus] + 1'b1;
				end
			end
		end

	end

endgenerate

endmodule

`endif // _CACHE_POLICY_CONTROLLER_FIFO_V_