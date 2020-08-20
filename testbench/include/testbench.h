`ifndef _TESTBENCH_H_
`define _TESTBENCH_H_

// top level model
`include "top.h"

// testbench configuration parameters
`define ITERATIONS 			10000	 	// iterations (cycles) to run
`define PERIOD_NS 			20 			// simulation period in nanoseconds
`define ADDRESS_LIMIT_BW  	16  		// 2**16 = 64kW = 256kB (max of HDL top level model)
`define READ_PERCENTAGE 	75 			// ratio of read operations to execute
//`define STOP_ON_ERROR  				// uncomment if the simulation should quit when an error is seen
										// otherwise it will continue and count the number of errors

`endif