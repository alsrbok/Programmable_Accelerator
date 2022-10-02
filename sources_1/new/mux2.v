//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: mux2
// Description:
//		mux2
//		
//
// History: 2022.08.09 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module mux2 #( parameter WIDTH = 16)
	(
    input [WIDTH-1:0] zero,
    input [WIDTH-1:0] one,
    input sel,
    output [WIDTH-1:0] out
    );
	
	assign out = sel ? one : zero;
	
endmodule
