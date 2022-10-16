//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: mux32
// Description:
//		mux32 for pe_array
//		
//
// History: 2022.08.31 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module mux32 #( parameter WIDTH = 16)
	(
    input [WIDTH*32-1:0] in,
    input [4:0] sel,
    output reg [WIDTH-1:0] out
    );
	
	always @(*) begin
        case (sel)
            5'b11111 : out = in[0+:WIDTH];
            5'b11110 : out = in[WIDTH*1+:WIDTH];
            5'b11101 : out = in[WIDTH*2+:WIDTH];
            5'b11100 : out = in[WIDTH*3+:WIDTH];
            5'b11011 : out = in[WIDTH*4+:WIDTH];
            5'b11010 : out = in[WIDTH*5+:WIDTH];
            5'b11001 : out = in[WIDTH*6+:WIDTH];
            5'b11000 : out = in[WIDTH*7+:WIDTH];
            5'b10111 : out = in[WIDTH*8+:WIDTH];
            5'b10110 : out = in[WIDTH*9+:WIDTH];
            5'b10101 : out = in[WIDTH*10+:WIDTH];
            5'b10100 : out = in[WIDTH*11+:WIDTH];
            5'b10011 : out = in[WIDTH*12+:WIDTH];
            5'b10010 : out = in[WIDTH*13+:WIDTH];
            5'b10001 : out = in[WIDTH*14+:WIDTH];
            5'b10000 : out = in[WIDTH*15+:WIDTH];
            5'b01111 : out = in[WIDTH*16+:WIDTH];
            5'b01110 : out = in[WIDTH*17+:WIDTH];
            5'b01101 : out = in[WIDTH*18+:WIDTH];
            5'b01100 : out = in[WIDTH*19+:WIDTH];
            5'b01011 : out = in[WIDTH*20+:WIDTH];
            5'b01010 : out = in[WIDTH*21+:WIDTH];
            5'b01001 : out = in[WIDTH*22+:WIDTH];
            5'b01000 : out = in[WIDTH*23+:WIDTH];
            5'b00111 : out = in[WIDTH*24+:WIDTH];
            5'b00110 : out = in[WIDTH*25+:WIDTH];
            5'b00101 : out = in[WIDTH*26+:WIDTH];
            5'b00100 : out = in[WIDTH*27+:WIDTH];
            5'b00011 : out = in[WIDTH*28+:WIDTH];
            5'b00010 : out = in[WIDTH*29+:WIDTH];
            5'b00001 : out = in[WIDTH*30+:WIDTH];
            5'b00000 : out = in[WIDTH*31+:WIDTH];
        endcase
    end
	
endmodule
/*
            5'b00000 : out = in[15:0];
            5'b00001 : out = in[31:16];
            5'b00010 : out = in[47:32];
            5'b00011 : out = in[63:48];
            5'b00100 : out = in[79:64];
            5'b00101 : out = in[95:80];
            5'b00110 : out = in[111:96];
            5'b00111 : out = in[127:112];
            5'b01000 : out = in[143:128];
            5'b01001 : out = in[159:144];
            5'b01010 : out = in[175:160];
            5'b01011 : out = in[191:176];
            5'b01100 : out = in[207:192];
            5'b01101 : out = in[223:208];
            5'b01110 : out = in[239:224];
            5'b01111 : out = in[255:240];
            5'b10000 : out = in[271:256];
            5'b10001 : out = in[287:272];
            5'b10010 : out = in[303:288];
            5'b10011 : out = in[319:304];
            5'b10100 : out = in[335:320];
            5'b10101 : out = in[351:336];
            5'b10110 : out = in[367:352];
            5'b10111 : out = in[383:368];
            5'b11000 : out = in[399:384];
            5'b11001 : out = in[415:400];
            5'b11010 : out = in[431:416];
            5'b11011 : out = in[447:432];
            5'b11100 : out = in[463:448];
            5'b11101 : out = in[479:464];
            5'b11110 : out = in[495:480];
            5'b11111 : out = in[511:496];
            */