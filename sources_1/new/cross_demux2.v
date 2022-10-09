//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: cross_demux2
// Description:
//		It send the input data to output reg by cross
//		
//
// History: 2022.10.08 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

`timescale 1ns / 1ps

module cross_demux2 #( parameter WIDTH = 16)
	(
    input [WIDTH-1:0] din0, din1,
    input sel,
    output reg [WIDTH-1:0] dout0,
    output reg [WIDTH-1:0] dout1
    );
	
	always@(*)begin
        if(sel == 1'b0) begin
            dout0 = din0;
            dout1 = din1;
        end
        else if(sel == 1'b1) begin
            dout0 = din1;
            dout1 = din0;
        end
        else begin
            dout0 = {WIDTH{1'bx}};
            dout1 = {WIDTH{1'bx}};
        end
    end
	
endmodule