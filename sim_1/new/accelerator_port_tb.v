//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: accelerator_port_tb
// Description:
//		testbench for accelerator_port
//      
//      
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module accelerator_port_tb ();
    parameter ROW         = 16;
    parameter COL                   = 16;
    parameter IN_BITWIDTH           = 8;
    parameter OUT_BITWIDTH          = 16;
    parameter ACTV_ADDR_BITWIDTH    = 2;
    parameter ACTV_DEPTH            = 4;
    parameter WGT_ADDR_BITWIDTH     = 2;
    parameter WGT_DEPTH             = 4;
    parameter PSUM_ADDR_BITWIDTH    = 2;
    parameter PSUM_DEPTH            = 4;
    parameter GBF_DATA_BITWIDTH     = 256;
    parameter GBF_ADDR_BITWIDTH     = 5;
    parameter GBF_DEPTH             = 32;
    parameter PSUM_GBF_DATA_BITWIDTH=512;
    parameter PSUM_GBF_ADDR_BITWIDTH= 5;
    parameter PSUM_GBF_DEPTH        = 32;

    reg clk, reset;
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    wire [PSUM_GBF_DATA_BITWIDTH/4-1:0] reduced_r_data1b, reduced_r_data2b;
    wire r_en1b_out, r_en2b_out;
    wire [31:0] initial_data1b;
    wire [31:0] initial_data2b;

    accelerator_port #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)) 
    u_accelerator_port(.clk(clk), .reset(reset), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data), .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), 
    .reduced_r_data1b(reduced_r_data1b), .reduced_r_data2b(reduced_r_data2b), .r_en1b_out(r_en1b_out), .r_en2b_out(r_en2b_out), .initial_data1b(initial_data1b), .initial_data2b(initial_data2b));

    always
        #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;
        #20 reset = 0;

    end
endmodule