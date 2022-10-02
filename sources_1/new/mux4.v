//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: mux4
// Description:
//		mux4
//		
//
// History: 2022.10.02 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module mux4 #( parameter WIDTH = 16)
	(
    input [WIDTH-1:0] in0,
    input [WIDTH-1:0] in1,
    input [WIDTH-1:0] in2,
    input [WIDTH-1:0] in3,
    input [1:0] sel,
    output reg [WIDTH-1:0] out
    );
	
	always @(*) begin
        case(sel)
            2'b00: out = in0;
            2'b01: out = in1;
            2'b10: out = in2;
            2'b11: out = in3;
        endcase
    end
	
endmodule
