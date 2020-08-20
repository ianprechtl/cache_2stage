// 1b-to-32b comparator

`ifndef _IDENTITY_COMPARATOR_V_
`define _IDENTITY_COMPARATOR_V_

module identity_comparator #(
	parameter BW = 0
)(
	input 	[BW-1:0]	opA_i,
	input 	[BW-1:0]	opB_i,
	output 				match_o 	// logic high if opA == opB
);

localparam BW_MATCHES = 	(BW <= 4) ? 1 : 
							(BW <= 8) ? 2 : 
							(BW <= 12) ? 3 : 
							(BW <= 16) ? 4 :
							(BW <= 20) ? 5 :
							(BW <= 24) ? 6 :
							(BW <= 28) ? 7 :
							(BW <= 32) ? 8 :
							0;
 
wire [BW_MATCHES-1:0]	match_bus;
assign match_o = &(match_bus);

genvar i;
generate
	for (i = 0; (4*i) < BW; i = i + 1) begin: identity_comp_array

		if ( (BW - (4*i)) >= 4 ) begin
			comparator_identity_4b_mod comp_inst(opA_i[(4*(i+1))-1:4*i], opB_i[(4*(i+1))-1:4*i], match_bus[i]);
		end
		else if ( (BW - (4*i)) == 3 ) begin
			comparator_identity_3b_mod comp_inst(opA_i[(4*(i+1))-2:4*i], opB_i[(4*(i+1))-2:4*i], match_bus[i]);
		end
		else if ( (BW - (4*i)) == 2 ) begin
			comparator_identity_2b_mod comp_inst(opA_i[(4*(i+1))-3:4*i], opB_i[(4*(i+1))-3:4*i], match_bus[i]);
		end
		else begin
			comparator_identity_1b_mod comp_inst(opA_i[(4*(i+1))-4:4*i], opB_i[(4*(i+1))-4:4*i], match_bus[i]);
		end

	end
endgenerate

endmodule



// dependency components
// ---------------------------------------------------------------------------------------------

module comparator_identity_4b_mod(
	input 	[3:0]		opA_i, opB_i,
	output 				match_o
);

wire 	[3:0]	node_xnor;

xnor xnor0(node_xnor[0], opA_i[0], opB_i[0]);
xnor xnor1(node_xnor[1], opA_i[1], opB_i[1]);
xnor xnor2(node_xnor[2], opA_i[2], opB_i[2]);
xnor xnor3(node_xnor[3], opA_i[3], opB_i[3]);

and and0(match_o, node_xnor[0], node_xnor[1], node_xnor[2], node_xnor[3]);

endmodule

module comparator_identity_3b_mod(
	input 	[2:0]		opA_i, opB_i,
	output 				match_o
);

wire 	[2:0]	node_xnor;

xnor xnor0(node_xnor[0], opA_i[0], opB_i[0]);
xnor xnor1(node_xnor[1], opA_i[1], opB_i[1]);
xnor xnor2(node_xnor[2], opA_i[2], opB_i[2]);

and and0(match_o, node_xnor[0], node_xnor[1], node_xnor[2]);

endmodule

module comparator_identity_2b_mod(
	input 	[1:0]		opA_i, opB_i,
	output 				match_o
);

wire 	[1:0]	node_xnor;

xnor xnor0(node_xnor[0], opA_i[0], opB_i[0]);
xnor xnor1(node_xnor[1], opA_i[1], opB_i[1]);

and and0(match_o, node_xnor[0], node_xnor[1]);

endmodule

module comparator_identity_1b_mod(
	input 				opA_i, opB_i,
	output 				match_o
);

wire 			node_xnor;

xnor xnor0(match_o, opA_i, opB_i);

endmodule

`endif