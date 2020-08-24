`ifndef _TESTBENCH_H_
`define _TESTBENCH_H_

// top level model
`include "top.h"

// testbench configuration parameters
`define TESTBENCH_ITERATIONS 			100000	 	// iterations (cycles) to run
`define TESTBENCH_PERIOD_NS 			20 			// simulation period in nanoseconds
`define TESTBENCH_ADDRESS_LIMIT_BW  	16  		// 2**16 = 64kW = 256kB (max of HDL top level model)
`define TESTBENCH_READ_PERCENTAGE 		75 			// ratio of read operations to execute
`define TESTBENCH_STOP_ON_ERROR  					// uncomment if the simulation should quit when an error is seen
													// otherwise it will continue and count the number of errors

`endif