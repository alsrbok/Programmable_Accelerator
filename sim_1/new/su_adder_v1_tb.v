//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_v1_tb
// Description:
//		testbench for su_adder_v1
//      
//      
//  
// History: 2022.09.27 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module su_adder_v1_tb ();

    parameter ROW                       = 16;
    parameter COL                       = 16;
    parameter DATA_BITWIDTH             = 16;
    parameter GBF_DATA_BITWIDTH         = 512;
    parameter PSUM_RF_ADDR_BITWIDTH     = 2;
    parameter DEPTH                     = 32;

    reg clk, reset;
    reg [DATA_BITWIDTH*ROW*COL-1:0] psum_out;
    reg pe_psum_finish, conv_finish;
    reg [4:0] irrel_num;      
    wire [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr;
    wire su_add_finish;
    wire [GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_gbf_w_en;
    wire [4:0] psum_gbf_w_addr;
    wire psum_gbf_w_num; 

    su_adder_v1 #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder_v1(.clk(clk), .reset(reset), .psum_out(psum_out), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .irrel_num(irrel_num),
    .psum_rf_addr(psum_rf_addr), .su_add_finish(su_add_finish), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num));

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;

        #10 reset = 0; pe_psum_finish = 1'b0; irrel_num=5'd7;

        #50
        //for irrel_num=5'd2;
        /*
        psum_out = {16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd1, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd2, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd3, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd3, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd4, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd4, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd5, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd6, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd6, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd7, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd8, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4};
        */
        //for irrel_num=5'd3 & 5'd5;
        
        psum_out = {16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f    irrel5 : a=7, b=f, c=17     irrel7 : a=c, b=1c
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f
                    16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd0, //a=6, b=f, c=6, d=f e=6    irrel5 : a=f, b=10, c=11    irrel7 : a=16, b=17
                    16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd0, //a=6, b=f, c=6, d=f e=6
                    16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd0, //a=6, b=f, c=6, d=f e=6
                    16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd0, //a=6, b=f, c=6, d=f e=6
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd5, 16'd2, 16'd2, 16'd3, 16'd6, 16'd5, 16'd6, 16'd1, 16'd1, 16'd1, 16'd0, //a=a, b=e, c=7, d=11 e=3   irrel5 : a=13, b=12, c=e    irrel7 : a=1a, b=18
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd5, 16'd2, 16'd2, 16'd3, 16'd6, 16'd5, 16'd6, 16'd1, 16'd1, 16'd1, 16'd0, //a=a, b=e, c=7, d=11 e=3
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd5, 16'd2, 16'd2, 16'd3, 16'd6, 16'd5, 16'd6, 16'd1, 16'd1, 16'd1, 16'd0, //a=a, b=e, c=7, d=11 e=3
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd5, 16'd2, 16'd2, 16'd3, 16'd6, 16'd5, 16'd6, 16'd1, 16'd1, 16'd1, 16'd0, //a=a, b=e, c=7, d=11 e=3
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f    irrel5 : a=7, b=f, c=17     irrel7 : a=c, b=1c
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0, //a=3, b=6, c=9, d=c e=f
                    16'd1, 16'd1, 16'd1, 16'd2, 16'd2, 16'd2, 16'd3, 16'd3, 16'd3, 16'd4, 16'd4, 16'd4, 16'd5, 16'd5, 16'd5, 16'd0}; //a=3, b=6, c=9, d=c e=f
        
        #10 // t=80,000ns
        pe_psum_finish = 1'b1;

        //#200 // t=280,000ns :end of calculation at irrel_num = 2
    end
    
endmodule