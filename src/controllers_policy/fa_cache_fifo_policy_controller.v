// cache address in the following form
//
// 		[set | group]
//

`ifndef _SET_CACHE_FIFO_POLICY_CONTROLLER_V_
`define _SET_CACHE_FIFO_POLICY_CONTROLLER_V_


module set_cache_fifo_policy_controller #(
	parameter CACHE_BLOCK_CAPACITY = 0

	`ifdef SIMULATION_SYNTHESIS
	,
	parameter BW_CACHE_CAPACITY 	= `CLOG2(CACHE_BLOCK_CAPACITY) // block addressible cache addresses
	`endif
)(
	input 								clock_i,
	input 								resetn_i,
	input 								miss_i, 		// pulse trigger to generate a replacement address
	output 								done_o, 		// logic high when replacement address generated
	output 	[BW_CACHE_CAPACITY-1:0] 	addr_o 			// replacement address generated
);

// parameterizations
// ------------------------------------------------------------------------------------------
localparam BW_FIFO 				= `CLOG2(CACHE_BLOCK_CAPACITY);

`ifndef SIMULATION_SYNTHESIS
localparam BW_CACHE_CAPACITY 	= `CLOG2(CACHE_BLOCK_CAPACITY); // block addressible cache addresses
`endif


// replacement controller
//  ------------------------------------------------------------------------------------------
reg 	[BW_FIFO-1:0]	 			replacement_counter_reg;
reg 								done_reg;
reg 	[BW_CACHE_CAPACITY-1:0] 	addr_reg; 					

assign done_o = done_reg;
assign addr_o = addr_reg;

integer i;
always @(posedge clock_i) begin

	// reset state
	// ---------------------------------------------------------------------------------------
	if (!resetn_i) begin
		replacement_counter_reg <= 'b0;
		done_reg 				<= 1'b0;
		addr_reg 				<= 'b0;
	end

	// active sequencing
	// ---------------------------------------------------------------------------------------
	else begin
		// only trigger controller on a miss
		if (miss_i) begin
			
			// set the replacement ptr to where the set fifo counter is pointing
			addr_reg <= replacement_counter_reg;
			done_reg <= 1'b1;

			// point to next location
			replacement_counter_reg <= replacement_counter_reg + 1'b1;
		end
	end

end

endmodule 

`endif