//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: demux4
// Description:
//		demux4
//		
//
// History: 2022.10.02 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

`timescale 1ns / 1ps

module demux4 #( parameter WIDTH = 16)
	(
    input [WIDTH-1:0] in,
    input [1:0] sel,
    output reg [WIDTH-1:0] out0,
    output reg [WIDTH-1:0] out1,
    output reg [WIDTH-1:0] out2,
    output reg [WIDTH-1:0] out3
    );
	
	always@(*)begin
        case(sel)
            2'b00:
            begin
                out0=in; out1={WIDTH{1'b0}}; out2={WIDTH{1'b0}}; out3={WIDTH{1'b0}};
            end
            2'b01:
            begin
                out0={WIDTH{1'b0}}; out1=in; out2={WIDTH{1'b0}}; out3={WIDTH{1'b0}};
            end
            2'b10:
            begin
                out0={WIDTH{1'b0}}; out1={WIDTH{1'b0}}; out2=in; out3={WIDTH{1'b0}};
            end
            2'b11:
            begin
                out0={WIDTH{1'b0}}; out1={WIDTH{1'b0}}; out2={WIDTH{1'b0}}; out3=in;
            end
        endcase
    end
	
endmodule