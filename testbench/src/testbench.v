`ifndef _TESTBENCH_V_
`define _TESTBENCH_V_

// simulation configurations
`timescale 1 ns / 1 ns

// simulation dependencies
`include "../include/testbench.h"

// simuation HDL
module testbench;

// test hardware
// -----------------------------------------------------------

// drivers
reg 						clock_control_reg;
wire						clock_rw_bus;
reg 						resetn_reg;
reg 						core_request_reg;
reg 						core_wren_reg;
reg [31:0]					core_addr_reg;
reg [`TOP_BW_DATA_WORD-1:0]	core_data_reg;

// sinks
wire 						stall_flag;
wire 						core_valid_flag;
wire [`TOP_BW_DATA_WORD-1:0]core_data_bus;

// hardware instantiation
top dut (
// generics
	.clock_control_i		(clock_control_reg 			),
	.clock_rw_i 			(clock_rw_bus 				),
	.resetn_i 				(resetn_reg 				),
	.stall_o 				(stall_flag 				),

	// drivers
	.core_request_i	 		(core_request_reg 			),	
	.core_wren_i	 		(core_wren_reg 				),
	.core_addr_i	 		(core_addr_reg 				),
	.core_data_i	 		(core_data_reg 				),

	// sinks
	.core_valid_o 			(core_valid_flag 			),
	.core_data_o 			(core_data_bus 				)
);


// clock generation
// ----------------------------------------------------------------------------------------------------------
always #(`PERIOD_NS>>1) clock_control_reg = ~clock_control_reg; 		// core and cache
assign clock_rw_bus = ~clock_control_reg; 								// external memory


// testbench control sequence
// ----------------------------------------------------------------------------------------------------------

// driver signals
reg [6:0] 						percentage_reg; 									// holds randomly generated number (7bit so can hold [0,99]) for r/w operation
reg [`ADDRESS_LIMIT_BW-1:0] 	address_gen_reg;	 								// stores randomly generated bounded address
reg [`TOP_BW_DATA_WORD-1:0]		data_gen_reg; 										// stores randomly generated write data value
reg [`TOP_BW_DATA_WORD-1:0] 	data_check_fifo 	[0:7]; 							// when a read is executed the instantaneous target value is stored here
																					// to preserve memory operation ordering
reg [2:0]						read_ptr_reg; 										// on a read operation this where the 'scoreboard' should check against 
																					// in the 'data_check_fifo'
reg [2:0]						write_ptr_reg; 										// on a read operation this where to store the access value in
																					// 'data_check_fifo'
reg [`TOP_BW_DATA_WORD-1:0] 	mem_array 			[0:2**`ADDRESS_LIMIT_BW-1]; 	// virtual external memory

// sink signals
reg [31:0]	counter_correct_reg, 	// counts number of correct cache returns
			counter_wrong_reg, 		// counts number of incorrect cache returns
			counter_read_reg, 		// counts number of testbench initiated read accesses
			counter_write_reg; 		// counts number of testbench initiated write accesses

integer i;


// scoreboard
always @(posedge clock_control_reg) begin
	if (!resetn_reg) begin
		// control signals
		read_ptr_reg 			= 'b0;
		// metric/result signals
		counter_correct_reg 	= 'b0;
		counter_wrong_reg 		= 'b0;
	end
	else begin
		if (core_valid_flag) begin
			if (core_data_bus != data_check_fifo[read_ptr_reg]) begin
				counter_wrong_reg = counter_wrong_reg + 1;
				$display("Error %t", $time);
				`ifdef STOP_ON_ERROR
					#(PERIOD_NS>>1);
					$stop;
				`endif
			end
			else begin
				counter_correct_reg = counter_correct_reg + 1;
			end
			read_ptr_reg = read_ptr_reg + 1'b1;
		end
	end
end


// testbench sequence
initial begin

	// initialize testbench
	// --------------------------------------------------------------------------------------
	$display("> Starting Simulation");

	// core signals
	core_wren_reg 		= 1'b0;
	core_addr_reg 		= 'b0;
	core_data_reg 		= 'b0;

	// control signals
	//read_ptr_reg 		= 'b0;
	write_ptr_reg 		= 'b0;
	percentage_reg 		= 'b0;
	address_gen_reg 	= 'b0;
	data_gen_reg 		= 'b0;

	// metric/result signals
	counter_correct_reg = 'b0;
	counter_wrong_reg 	= 'b0;
	counter_read_reg 	= 'b0;
	counter_write_reg 	= 'b0;

	for (i = 0; i < 2**`ADDRESS_LIMIT_BW; i = i + 1) mem_array[i] = i[`ADDRESS_LIMIT_BW-1:0];
	for (i = 0; i < 8; i = i + 1) data_check_fifo[i] = 'b0;

	// reset hold, pull out of reset on posedge (sync. reset)
	clock_control_reg 	= 1'b0;
	resetn_reg  		= 1'b0;
	#(5*`PERIOD_NS);
	@(posedge clock_control_reg);
	resetn_reg  		= 1'b1;


	// testbench block
	// --------------------------------------------------------------------------------------
	repeat(`ITERATIONS) begin

		// core is posedge triggered so make all requests and verifications on this edge
		@(posedge clock_control_reg);

		// generate request and write its contents to array
		if (!stall_flag)begin

			// request generation - read / or write
			// and address of access
			percentage_reg 					= $urandom() % 100;
			address_gen_reg 				= $urandom() % 2**`ADDRESS_LIMIT_BW;

			// read	access
			// write instantaneous memory value to data check fifo
			// and execute request to cache top level
			if (percentage_reg < `READ_PERCENTAGE) begin	
				data_check_fifo[write_ptr_reg] = mem_array[address_gen_reg];
				write_ptr_reg 					= write_ptr_reg + 1'b1;
				core_addr_reg 					= address_gen_reg << 2; 		// shift by two bc byte address get converted to word address
				core_request_reg 				= 1'b1;
				core_wren_reg 					= 1'b0;
				counter_read_reg 				= counter_read_reg + 1'b1;
			end
			// write access
			// write generated value to virtual memory
			else begin
				data_gen_reg  					= $urandom();
				mem_array[address_gen_reg] 		= data_gen_reg;
				core_wren_reg 					= 1'b1;
				core_addr_reg 					= address_gen_reg << 2; 		// shift by two bc byte address get converted to word address
				core_request_reg 				= 1'b1;
				core_data_reg 					= data_gen_reg;
				counter_write_reg 				= counter_write_reg + 1'b1;
			end
		end

		// if the cache is stalled due to a miss do not make any new request
		// - the core operates this way
		else begin
			core_request_reg 				= 1'b0;
			core_wren_reg 					= 1'b0;
		end
	end

	// testbench results
	// --------------------------------------------------------------------------------------
	$display("> Simulation Results");
	$display("> Correct:\t%d", counter_correct_reg);
	$display("> Errors:\t%d", counter_wrong_reg);
	$display("> Read Acceses:\t%d (%0d%%)",counter_read_reg,100*counter_read_reg/(counter_read_reg+counter_write_reg));
	$display("> Write Accesses:\t%d",counter_write_reg);
	$stop;

end

endmodule

`endif