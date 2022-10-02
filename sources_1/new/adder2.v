//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: adder2
// Description:
//		It just adds two inputs
//      
//      
//  
// History: 2022.09.27 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module adder2 #(parameter DATA_BITWIDTH         = 16)
              ( input [DATA_BITWIDTH-1:0] left, right,
                output [DATA_BITWIDTH-1:0] out);

    assign out = left + right;

endmodule