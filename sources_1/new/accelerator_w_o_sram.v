//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: accelerator_w_o_sram
// Description:
//		gbf_pe_array_su_adder + psum_gbf_wrapper
//      
//      
//  
// History: 2022.10.08 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module accelerator_w_o_sram #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 16,   //For activation. weight, partial psum
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH     = 512,
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
            //output of psum_gbf_wrapper
            output [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b,
            output [PSUM_GBF_DATA_BITWIDTH-1:0] r_data2b,
            output r_en1b_out, r_en2b_out);

    wire [PSUM_GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_gbf_w_en;
    wire [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr;
    wire psum_gbf_w_num;
    wire psum_gbf_r_en;
    wire [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_r_addr;
    wire psum_gbf_w_en_for_init;
    wire [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr_for_init;

    gbf_pe_array_su_adder #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)
    ) u_gbf_pe_array_su_adder(.clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num), .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init));

    psum_gbf_wrapper #(.ROW(ROW), .COL(COL), .OUT_BITWIDTH(OUT_BITWIDTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)
    ) u_psum_gbf_wrapper(.clk(clk), .reset(reset), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num), .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init),
    .r_data1b_out(r_data1b), .r_data2b_out(r_data2b), .r_en1b_out(r_en1b_out), .r_en2b_out(r_en2b_out));
 
endmodule