//------------------------------------------------------------+
// Project: Spatial Accelerator
// Module: gbf_controller_tb
// Description:
//		testbench for gbf_controller
//      
//      
//
// History: 2022.09.12 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module gbf_controller_tb();
    parameter ROW          = 16;
    parameter COL                           = 16;
    parameter ACTV_ADDR_BITWIDTH            = 2;
    parameter WGT_ADDR_BITWIDTH             = 2;
    parameter GBF_DATA_BITWIDTH             = 512;
    parameter GBF_ADDR_BITWIDTH             = 5;
    parameter GBF_DEPTH                     = 32;
    reg clk, reset, finish;
    reg gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;
    reg rf_finish_turn_off, actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data;
    wire [GBF_ADDR_BITWIDTH-1:0] actv_gbf_addrb, wgt_gbf_addrb;
    wire actv_mux_gbf2rf, wgt_mux_gbf2rf;
    wire actv_gbf_en1b, actv_gbf_en2b, wgt_gbf_en1b, wgt_gbf_en2b;
    wire [3:0] actv_mux32_addr, wgt_mux32_addr;
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    wire [ROW*COL-1:0] rf_actv_en; wire [ACTV_ADDR_BITWIDTH-1:0] rf_actv_w_addr;
    wire [ROW*COL-1:0] rf_wgt_en; wire [WGT_ADDR_BITWIDTH-1:0] rf_wgt_w_addr;
    wire rf_actv_data_avail, rf_wgt_data_avail, rf_actv_send_finish, rf_wgt_send_finish;
    wire conv_finish;

    gbf_controller #(.ROW(ROW), .COL(COL), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH)) u_gbf_controller(.clk(clk),
    .reset(reset), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail), 
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), 
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

        #175 //200ns nxt state is set to S2
            ;
        #170 //370ns nxt state is set to WAIT
            ;
        
        #20 //390ns nxt state is set to init_S3
        gbf_actv_buf2_ready = 1'b1;
        #10 //400ns nxt state is set to S3
        gbf_actv_buf1_ready = 1'b0; //due to actv_gbf1_need_data become 1, gbf_buf1 get new data from sram

        #10 //one cycle is delayed at first time => it can be modified by change posedge/negedge (but it need time for enable signal to be sent)
            ;
        #160 // 570ns nxt state is set to init_S3
            ;
        #10 // 580ns nxt state is set to S3
            ;
        #10 // one cycle is delayer
        gbf_actv_buf1_ready = 1'b1;

        #160 // 750ns nxt state is set to init_S3
        ;//gbf_actv_buf2_ready = 1'b0; : It should be changed to 1'b0 but, i don't care it from now

        #10 // 760ns nxt state is set to S3
        ;
        
        //wgt irrel is finished at 41,450ns : It became to WAIT state since gbf_wgt_buf2_ready is 1'b0.
        //$stop;
    end

endmodule