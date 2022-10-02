//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: gbf_db
// Description:
//		Global Buffer Module for Activation and Weight
//		It contains two simple_dp_rams = Double buffering
//		
//
// History: 2022.09.17 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module gbf_db #(parameter DATA_BITWIDTH   = 512,
                parameter ADDR_BITWIDTH   = 5,
                parameter DEPTH           = 32,
                parameter MEM_INIT_FILE1 = "",
                parameter MEM_INIT_FILE2 = "" )
              ( input clk, en1a, en1b, we1a, en2a, en2b, we2a,
                input [ADDR_BITWIDTH-1 : 0] addr1a, addr1b, addr2a, addr2b,
                input [DATA_BITWIDTH-1 : 0] w_data1a, w_data2a, 
                output [DATA_BITWIDTH-1 : 0] r_data1b, r_data2b
    );

    simple_dp_ram #(.DATA_BITWIDTH(DATA_BITWIDTH), .ADDR_BITWIDTH(ADDR_BITWIDTH), .DEPTH(DEPTH), .MEM_INIT_FILE(MEM_INIT_FILE1)) gbf_buffer1(
        .clk(clk), .ena(en1a),.enb(en1b), .wea(we1a), .addra(addr1a), .addrb(addr1b), .dia(w_data1a), .dob(r_data1b));

    simple_dp_ram #(.DATA_BITWIDTH(DATA_BITWIDTH), .ADDR_BITWIDTH(ADDR_BITWIDTH), .DEPTH(DEPTH), .MEM_INIT_FILE(MEM_INIT_FILE2)) gbf_buffer2(
        .clk(clk), .ena(en2a), .enb(en2b), .wea(we2a), .addra(addr2a), .addrb(addr2b), .dia(w_data2a), .dob(r_data2b));


endmodule