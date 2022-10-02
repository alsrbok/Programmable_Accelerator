//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: adder3
// Description:
//		It adds three inputs
//      
//      
//  
// History: 2022.09.27 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module adder3 #(parameter DATA_BITWIDTH         = 16)
              ( input [DATA_BITWIDTH-1:0] in0, in1, in2,
                output [DATA_BITWIDTH-1:0] out);

    assign out = in0 + in1 + in2;

endmodule