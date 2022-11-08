//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: gbf_pe_array_su_adder
// Description:
//		gbf_pe_array + su_adder
//      
//      
//  
// History: 2022.10.02 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module gbf_pe_array_su_adder #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight, partial psum
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH     = 256,
            parameter GBF_ADDR_BITWIDTH     = 5,    //Addr Bitwidth for actv/wgt gbf
            parameter GBF_DEPTH             = 32,   //Depth for actv/wgt gbf
            parameter PSUM_GBF_DATA_BITWIDTH= 512,
            parameter PSUM_GBF_ADDR_BITWIDTH= 5,    //Addr Bitwidth for psum gbf
            parameter PSUM_GBF_DEPTH        = 32) //Depth for psum gbf
        (   input clk, reset,
            //input for actv/wgt gbf buffer
            input actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a, 
            input [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a,
            input [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a,
            //input for gbf_controller
            input finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready,
            //output of gbf_controller
            output actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data,
            //su_adder
            output [PSUM_GBF_DATA_BITWIDTH-1:0] out_data,                        //output data for psum_gbf
            output psum_gbf_w_en,                                           //write enable for psum_gbf
            output [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr,            //write address for psum_gbf
            output psum_gbf_w_num,                                          //currently, write data to psum_gbf buf 1(0) / 2(1)
            output psum_gbf_r_en,                                           //read enable for psum_gbf
            output [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_r_addr,            //read address for psum_gbf
            output psum_gbf_w_en_for_init,                                  //write enable in order to initialize the psum
            output [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr_for_init    //write address in order to initialize the psum
            //output r0_psum_gbf_w_num, r1_psum_gbf_w_num, r2_psum_gbf_w_num
            );

    wire w_su_add_finish;
    wire [PSUM_ADDR_BITWIDTH-1:0] w_addr_from_su_adder;
    wire w_pe_psum_finish, w_conv_finish, w_turn_off;
    wire [OUT_BITWIDTH*ROW*COL-1:0] w_psum_out;

    gbf_pe_array #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH)) u_gbf_pe_array(.clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .addr_from_su_adder(w_addr_from_su_adder), .su_add_finish(w_su_add_finish), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .pe_psum_finish(w_pe_psum_finish), .conv_finish(w_conv_finish), .turn_off(w_turn_off), .psum_out(w_psum_out));

    su_adder #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(OUT_BITWIDTH), .GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH),
    .DEPTH(PSUM_GBF_DEPTH)) u_su_adder(.clk(clk), .reset(reset), .psum_out(w_psum_out), .pe_psum_finish(w_pe_psum_finish), .conv_finish(w_conv_finish),
    .psum_rf_addr(w_addr_from_su_adder), .su_add_finish(w_su_add_finish), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num),
    .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init)
    /*.r0_psum_gbf_w_num(r0_psum_gbf_w_num), .r1_psum_gbf_w_num(r1_psum_gbf_w_num), .r2_psum_gbf_w_num(r2_psum_gbf_w_num)*/);

endmodule