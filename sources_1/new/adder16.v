//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: adder16
// Description:
//		It adds 16 inputs

// History: 2022.09.27 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module adder16 #(parameter DATA_BITWIDTH         = 16)
              ( input [DATA_BITWIDTH-1:0] in0, in1, in2, in3, in4, in5, in6, in7, in8, in9, in10, in11, in12, in13, in14, in15,
                output [DATA_BITWIDTH-1:0] out);

    assign out = in0+ in1+ in2+ in3+ in4+ in5+ in6+ in7+ in8+ in9+ in10+ in11+ in12+ in13+ in14+ in15;

endmodule