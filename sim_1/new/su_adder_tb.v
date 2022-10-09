//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_tb
// Description:
//		testbench for su_adder
//      
//      
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module su_adder_tb ();

    parameter ROW                       = 16;
    parameter COL                       = 16;
    parameter DATA_BITWIDTH             = 16;
    parameter GBF_DATA_BITWIDTH         = 512;
    parameter PSUM_RF_ADDR_BITWIDTH     = 2;
    parameter GBF_ADDR_BITWIDTH         = 5;
    parameter DEPTH                     = 32;

    reg clk, reset;
    reg [DATA_BITWIDTH*ROW*COL-1:0] psum_out;
    reg pe_psum_finish, conv_finish;
    reg [4:0] irrel_num;  
    reg [4:0] rel_num; 
    wire [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr;
    wire su_add_finish;
    wire [GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_gbf_w_en;
    wire [4:0] psum_gbf_w_addr;
    wire psum_gbf_w_num;
    wire psum_gbf_r_en;
    wire [4:0] psum_gbf_r_addr;
    wire psum_gbf_w_en_for_init;
    wire [4:0] psum_gbf_w_addr_for_init;

    su_adder #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder(.clk(clk), .reset(reset), .psum_out(psum_out), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish),
    .psum_rf_addr(psum_rf_addr), .su_add_finish(su_add_finish), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num),
    .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init));

    integer i;

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;

        #10 reset = 0; pe_psum_finish = 1'b0; irrel_num=5'd4; rel_num=5'd3;

        #50
        //for irrel_num=5'd3 & 5'd5;
        /*
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
        */
                   
       psum_out = {16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd3, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd4, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd5, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd6, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4,
                    16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd1, 16'd2, 16'd3, 16'd4,
                    16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd2, 16'd3, 16'd4, 16'd5,
                    16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd8, 16'd7, 16'd6, 16'd5,
                    16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4, 16'd3, 16'd2, 16'd7, 16'd6, 16'd5, 16'd4};
        
        /*      
        psum_out = {16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, //0010
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, //000f
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, //000e
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, //000d
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, //000c
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000b
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000a
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //0009
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, //0010
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, //000f
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, //000e
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, //000d
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, //000c
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000b
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000a
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0}; //0009
        */
        #10 // t=80,000ns
        pe_psum_finish = 1'b1;
        /*
        $display("irrel_num : %d", u_su_adder.irrel_rel_num[0]);
        $display("rel_num : %d", u_su_adder.irrel_rel_num[1]);
        for(i=0; i<10; i=i+1) begin
        #10
        $display($time);
        $display("psum_out w0 : %h", u_su_adder.w0_psum_out);
        $display("psum_out w1 : %h", u_su_adder.w1_psum_out);
        $display("psum_out w2 : %h", u_su_adder.w2_psum_out);
        $display("out_data w0 : %h", u_su_adder.w0_out_data);
        $display("out_data w1 : %h", u_su_adder.w1_out_data);
        $display("out_data w2 : %h", u_su_adder.w2_out_data);
        end*/

        //#200 // t=280,000ns :end of calculation at irrel_num = 2

        #2140
        pe_psum_finish = 1'b0;

        #50
        pe_psum_finish = 1'b1;
    end
    
endmodule