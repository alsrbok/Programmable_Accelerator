//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: basic_adder
// Description:
//		It is a fundamental element for su_adder_v1
//      It can make output of a or b or a+b or 0
//      
//  
// History: 2022.09.26 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module basic_adder #(parameter DATA_BITWIDTH         = 16)
              ( input [DATA_BITWIDTH-1:0] left, right,
                input [1:0] mode,   //mode for basic_adder
                output reg [DATA_BITWIDTH-1:0] out);

    always @(*) begin
        case(mode)
            2'b00:      out = left;
            2'b01:      out = right;
            2'b10:      out = left+right;
            2'b11:      out = {DATA_BITWIDTH{1'b0}};
            default:    out = {DATA_BITWIDTH{1'bx}};
        endcase
    end

endmodule