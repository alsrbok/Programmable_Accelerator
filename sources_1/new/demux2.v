//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: demux2
// Description:
//		demux2
//		
//
// History: 2022.08.09 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

`timescale 1ns / 1ps

module demux2 #( parameter WIDTH = 16)
	(
    input [WIDTH-1:0] d_in,
    input sel,
    output reg [WIDTH-1:0] zero,
    output reg [WIDTH-1:0] one
    );
	
	always@(*)begin
        if(sel == 1'b0) begin
            zero = d_in;
            one = 0;
        end
        else if(sel == 1'b1) begin
            zero = 0;
            one = d_in;
        end
        else begin
            zero = 1'bX;
            one = 1'bX;
        end
    end
	
endmodule