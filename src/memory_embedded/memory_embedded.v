`ifndef _MEMORY_EMBEDDED_V_
`define _MEMORY_EMBEDDED_V_

module memory_embedded #(
	parameter N_ENTRIES 	= 0,
	parameter BW_DATA 		= 0,
	parameter DEBUG 		= 0, 	// if 1 sets the BRAM to dual port so in memory content editor
	parameter INIT_PATH 	= ""

`ifdef SIMULATION_SYNTHESIS ,
	parameter BW_ADDR 	= `CLOG2(N_ENTRIES)
`endif
)(
	input 					clock_i,
	input 					wren_i,
	input 	[BW_ADDR-1:0]	addr_i,
	input 	[BW_DATA-1:0]	data_i,
	output 	[BW_DATA-1:0]	data_o
);

// local parameterizations for instance overriding
localparam LPM_HINT = (DEBUG) ? "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=inst" : 
								"ENABLE_RUNTIME_MOD=NO";
`ifndef SIMULATION_SYNTHESIS
localparam BW_ADDR 	= `CLOG2(N_ENTRIES);
`endif

// ip instance
// -----------------------------------------------------------
altsyncram	altsyncram_component (
	.address_a 			(addr_i 		),
	.clock0 			(clock_i 		),
	.data_a 			(data_i 		),
	.wren_a 			(wren_i			),
	.q_a 				(data_o 		),
	.aclr0 				(1'b0 			),
	.aclr1 				(1'b0			),
	.address_b 			(1'b1 			),
	.addressstall_a 	(1'b0			),
	.addressstall_b 	(1'b0			),
	.byteena_a 			(1'b1 			),
	.byteena_b 			(1'b1 			),
	.clock1 			(1'b1 			),
	.clocken0 			(1'b1 			),
	.clocken1 			(1'b1 			),
	.clocken2 			(1'b1 			),
	.clocken3 			(1'b1 			),
	.data_b 			(1'b1 			),
	.eccstatus 			( 				),
	.q_b 				( 				),
	.rden_a 			(1'b1 			),
	.rden_b 			(1'b1 			),
	.wren_b 			(1'b0			)
);

// static parameterizations
defparam
	altsyncram_component.clock_enable_input_a 			= "BYPASS",
	altsyncram_component.clock_enable_output_a 			= "BYPASS",
	altsyncram_component.intended_device_family 		= "Cyclone V",
	altsyncram_component.lpm_type 						= "altsyncram",
	altsyncram_component.operation_mode 				= "SINGLE_PORT",
	altsyncram_component.outdata_aclr_a 				= "NONE",
	altsyncram_component.outdata_reg_a 					= "UNREGISTERED",
	altsyncram_component.power_up_uninitialized			= "FALSE",
	altsyncram_component.read_during_write_mode_port_a 	= "DONT_CARE",
	altsyncram_component.width_byteena_a 				= 1;

// configurable parameterizations
defparam
	altsyncram_component.lpm_hint 						= LPM_HINT,
	altsyncram_component.width_a 						= BW_DATA,
	altsyncram_component.numwords_a 					= N_ENTRIES,
	altsyncram_component.widthad_a 						= BW_ADDR,
	altsyncram_component.init_file  					= INIT_PATH;

endmodule

`endif