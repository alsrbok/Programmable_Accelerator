//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: gbf_controller_new_tb
// Description:
//		testbench for gbf_controller_neg
//      
//      
//
// History: 2022.09.16 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module gbf_controller_new_tb();
    parameter ROW          = 16;
    parameter COL                           = 16;
    parameter ACTV_ADDR_BITWIDTH            = 2;
    parameter WGT_ADDR_BITWIDTH             = 2;
    parameter GBF_DATA_BITWIDTH             = 512;
    parameter GBF_ADDR_BITWIDTH             = 5;
    parameter GBF_DEPTH                     = 32;
    reg clk, reset, finish;
    reg gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;
    reg rf_turn_off, actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data;
    wire [GBF_ADDR_BITWIDTH-1:0] actv_gbf_addrb, wgt_gbf_addrb;
    wire actv_mux_gbf2rf, wgt_mux_gbf2rf;
    wire actv_gbf_en1b, actv_gbf_en2b, wgt_gbf_en1b, wgt_gbf_en2b;
    wire [3:0] actv_mux32_addr, wgt_mux32_addr;
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    wire [ROW*COL-1:0] rf_actv_en; wire [ACTV_ADDR_BITWIDTH-1:0] rf_actv_w_addr;
    wire [ROW*COL-1:0] rf_wgt_en; wire [WGT_ADDR_BITWIDTH-1:0] rf_wgt_w_addr;
    wire rf_actv_data_avail, rf_wgt_data_avail, rf_actv_send_finish, rf_wgt_send_finish;
    wire conv_finish;

    gbf_controller_old #(.ROW(ROW), .COL(COL), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH)) u_gbf_controller_new(.clk(clk),
    .reset(reset), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail), 
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready),
    .rf_turn_off(rf_turn_off), .actv_rf1_need_data(actv_rf1_need_data), .actv_rf2_need_data(actv_rf2_need_data), .wgt_rf1_need_data(wgt_rf1_need_data), .wgt_rf2_need_data(wgt_rf2_need_data),
    .actv_gbf_addrb(actv_gbf_addrb), .wgt_gbf_addrb(wgt_gbf_addrb), .actv_mux_gbf2rf(actv_mux_gbf2rf), .wgt_mux_gbf2rf(wgt_mux_gbf2rf), 
    .actv_gbf_en1b(actv_gbf_en1b), .actv_gbf_en2b(actv_gbf_en2b), .wgt_gbf_en1b(wgt_gbf_en1b), .wgt_gbf_en2b(wgt_gbf_en2b),
    .actv_mux32_addr(actv_mux32_addr), .wgt_mux32_addr(wgt_mux32_addr), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data), 
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .rf_actv_en(rf_actv_en), .rf_actv_w_addr(rf_actv_w_addr),
    .rf_wgt_en(rf_wgt_en), .rf_wgt_w_addr(rf_wgt_w_addr), .rf_actv_data_avail(rf_actv_data_avail), .rf_wgt_data_avail(rf_wgt_data_avail), 
    .rf_actv_send_finish(rf_actv_send_finish), .rf_wgt_send_finish(rf_wgt_send_finish), .conv_finish(conv_finish));

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;
        gbf_actv_buf1_ready = 1'b1; gbf_actv_buf2_ready = 1'b0; gbf_wgt_buf1_ready = 1'b1; gbf_wgt_buf2_ready = 1'b0;
        #10 reset = 1;

        #10 reset = 0;

        #5 //25ns S1 state : actv_data_avail become 1
        gbf_actv_data_avail = 1'b1; gbf_wgt_data_avail = 1'b1; // input of gbf_actv_data_avail should be set at posedge

        #10 // when pe_array_controller become S1, they set need_data signal
        actv_rf1_need_data=1'b1; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b1;

        #165 //200ns nxt state is set to S2
            ;

        #10 // when pe_array_controller become S2, they set need_data signal
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #160 //370ns nxt state is set to WAIT
            ;
        #10 // when pe_array_controller become init_S3, they set need_data signal
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;

        #10 //390ns nxt state is set to init_S3
        gbf_actv_buf2_ready = 1'b1;
        #10 //400ns nxt state is set to S3
        gbf_actv_buf1_ready = 1'b0; //due to actv_gbf1_need_data become 1, gbf_buf1 get new data from sram

        #70 //470ns nxt state is changed to WAIT (case 1:  MAC operation is not end before the end of sending data)
            ;
        
        #70 //540ns pe_array_controller become init_S3 and flip need_data
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;


        #70 // 610ns : end of sending data

        #20 //630ns pe_array_controller become init_S3 and flip need_data (case 2: MAC opertaion is faster)
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;

        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =1 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =2 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =3 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =4 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =5 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =6 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        //irrel =7 for wgt
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b1; wgt_rf2_need_data=1'b0;
        #90
        actv_rf1_need_data=1'b0; actv_rf2_need_data=1'b1; wgt_rf1_need_data=1'b0; wgt_rf2_need_data=1'b1;



        
        //$stop;
    end

endmodule