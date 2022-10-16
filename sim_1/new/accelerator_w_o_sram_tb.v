//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: accelerator_w_o_sram_tb
// Description:
//		testbench for accelerator_w_o_sram
//      
//      
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module accelerator_w_o_sram_tb ();
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
    reg actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a;
    reg [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a;
    reg [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a;
    reg finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data2b;
    wire r_en1b_out, r_en2b_out;

    accelerator_w_o_sram #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)) u_accelerator_w_o_sram(
    .clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .r_data1b(r_data1b), .r_data2b(r_data2b), .r_en1b_out(r_en1b_out), .r_en2b_out(r_en2b_out));

    always
        #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;
        gbf_actv_buf1_ready = 1'b1; gbf_actv_buf2_ready = 1'b1; gbf_wgt_buf1_ready = 1'b1; gbf_wgt_buf2_ready = 1'b1; 

        #10 reset = 1;

        #10 reset = 0;

        #5//25ns gbf controller is setting to S1 state : actv_data_avail become 1 : At this time, buf1 is not send data
        gbf_actv_data_avail = 1'b1; gbf_wgt_data_avail = 1'b1;
        ;

        for(i=0; i<300; i=i+1) begin
            #5
            $display($time, " [psum_gbf_wrapper] psum_gbf_w_num : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.psum_gbf_w_num);
            $display($time, " [psum_gbf_wrapper] r_data1b_from_gbf : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data1b_from_gbf);
            $display($time, " [psum_gbf_wrapper] r_data1b_for_add : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data1b_for_add);
            $display($time, " [psum_gbf_wrapper] r_data1b_out : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data1b_out);
            $display($time, " [psum_gbf_wrapper] r_data2b_from_gbf : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data2b_from_gbf);
            $display($time, " [psum_gbf_wrapper] r_data2b_for_add : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data2b_for_add);
            $display($time, " [psum_gbf_wrapper] r_data2b_out : %h", u_accelerator_w_o_sram.u_psum_gbf_wrapper.r_data2b_out);
        end
    end
endmodule

//wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b_for_add, r_data1b, r_data2b_for_add, r_data2b;
//demux2 #(.WIDTH(PSUM_GBF_DATA_BITWIDTH)) rdata1b_dmux(.d_in(r_data1b), .sel(psum_gbf_w_num), .zero(r_data1b_for_add), .one(r_data1b_out));
//demux2 #(.WIDTH(PSUM_GBF_DATA_BITWIDTH)) rdata2b_dmux(.d_in(r_data2b), .sel(psum_gbf_w_num), .zero(r_data2b_out), .one(r_data2b_for_add));