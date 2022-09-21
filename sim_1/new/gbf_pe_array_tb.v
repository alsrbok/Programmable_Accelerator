//------------------------------------------------------------+
// Project: Spatial Accelerator
// Module: gbf_controller_new_tb
// Description:
//		testbench for gbf_pe_array
//      
//      
//
// History: 2022.09.17 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps
`define FPGA 0

module gbf_pe_array_tb();
    parameter ROW         = 16;
    parameter COL                   = 16;
    parameter IN_BITWIDTH           = 16;
    parameter OUT_BITWIDTH          = 16;
    parameter ACTV_ADDR_BITWIDTH    = 2;
    parameter ACTV_DEPTH            = 4;
    parameter WGT_ADDR_BITWIDTH     = 2;
    parameter WGT_DEPTH             = 4;
    parameter PSUM_ADDR_BITWIDTH    = 2;
    parameter PSUM_DEPTH            = 4;
    parameter GBF_DATA_BITWIDTH     = 512;
    parameter GBF_ADDR_BITWIDTH     = 5;
    parameter GBF_DEPTH             = 32;
    reg clk, reset;
    //input for actv/wgt gbf buffer
    reg actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a;
    reg [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a;
    reg [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a;
    //input for gbf_controller
    reg finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;
    //input for actv/wgt_en_BRAM
    //input for actv/wgt_mux32_BRAM
    //input for pe_array_w_controller
    reg [PSUM_ADDR_BITWIDTH-1:0] addr_from_su_adder;
    reg su_add_finish;
    //output of gbf_controller
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    //output of pe_array_w_controller
    wire pe_psum_finish, conv_finish, turn_off;
    wire [OUT_BITWIDTH*ROW*COL-1:0] psum_out;

    gbf_pe_array #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH)) u_gbf_pe_array(.clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .addr_from_su_adder(addr_from_su_adder), .su_add_finish(su_add_finish), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .turn_off(turn_off), .psum_out(psum_out));

    always
        #5 clk = ~clk;

    integer i;
    
    initial begin
        clk = 0;
        //IDLE state
        reset = 0;
        gbf_actv_buf1_ready = 1'b1; gbf_actv_buf2_ready = 1'b1; gbf_wgt_buf1_ready = 1'b1; gbf_wgt_buf2_ready = 1'b1; 
        su_add_finish=1'b1; //su_add_finish should be set 1 initially (since su_adder can get partial sum data, pe_array_controller need 1 to move to init_S3 from S2)

        #10 reset = 1;

        #10 reset = 0;

        #5//25ns gbf controller is setting to S1 state : actv_data_avail become 1 : At this time, buf1 is not send data
        gbf_actv_data_avail = 1'b1; gbf_wgt_data_avail = 1'b1;
        $display($time, " [gbf_controller] wgt_en1b : %h", u_gbf_pe_array.wire_wgt_en1b);
        $display($time, " [gbf_controller] wgt_addr1b : %h", u_gbf_pe_array.wire_wgt_addr1b);
        $display($time, " [gbf_controller] wgt_r_data1b : %h", u_gbf_pe_array.wire_wgt_r_data1b);
        $display($time, " [en_BRAM] wire_wgt_en : %h", u_gbf_pe_array.wire_wgt_en);
        $display($time, " [mux32_BRAM] wire_wgt_mux32_dob : %h", u_gbf_pe_array.wire_wgt_mux32_dob);
        $display($time, " [pe_array] wire_rf_wgt_w_addr : %h", u_gbf_pe_array.wire_rf_wgt_w_addr);
        $display($time, " [pe_array] wire_rf_wgt_buf1_send_finish : %h", u_gbf_pe_array.wire_rf_wgt_buf1_send_finish);
        $display($time, " [pe_array] wire_rf_wgt_buf2_send_finish : %h", u_gbf_pe_array.wire_rf_wgt_buf2_send_finish);
        $display($time, " [gbf_controller] wgt_rf_num : %h", u_gbf_pe_array.u_gbf_controller_new.wgt_rf_num);
        $display($time, " [pe_array] wire_wgt_rf1_need_data : %h", u_gbf_pe_array.wire_wgt_rf1_need_data);
        $display($time, " [pe_array] wire_wgt_rf2_need_data : %h", u_gbf_pe_array.wire_wgt_rf2_need_data);
        $display($time, " [gbf_controller] actv_en1b : %h", u_gbf_pe_array.wire_actv_en1b);
        $display($time, " [gbf_controller] actv_addr1b : %h", u_gbf_pe_array.wire_actv_addr1b);
        $display($time, " [gbf_controller] actv_r_data1b : %h", u_gbf_pe_array.wire_actv_r_data1b);
        $display($time, " [en_BRAM] wire_actv_en : %h", u_gbf_pe_array.wire_actv_en);
        $display($time, " [mux32_BRAM] wire_actv_mux32_dob : %h", u_gbf_pe_array.wire_actv_mux32_dob);
        $display($time, " [pe_array] wire_rf_actv_w_addr : %h", u_gbf_pe_array.wire_rf_actv_w_addr);
        $display($time, " [pe_array] wire_rf_actv_buf1_send_finish : %h", u_gbf_pe_array.wire_rf_actv_buf1_send_finish);
        $display($time, " [pe_array] wire_rf_actv_buf2_send_finish : %h", u_gbf_pe_array.wire_rf_actv_buf2_send_finish);
        $display($time, " [gbf_controller] actv_rf_num : %h", u_gbf_pe_array.u_gbf_controller_new.actv_rf_num);
        $display($time, " [pe_array] wire_actv_rf1_need_data : %h", u_gbf_pe_array.wire_actv_rf1_need_data);
        $display($time, " [pe_array] wire_actv_rf2_need_data : %h", u_gbf_pe_array.wire_actv_rf2_need_data);

        for(i=0; i<300; i=i+1) begin
            #5
            $display($time, " [gbf_controller] wgt_en1b : %h", u_gbf_pe_array.wire_wgt_en1b);
            $display($time, " [gbf_controller] wgt_addr1b : %h", u_gbf_pe_array.wire_wgt_addr1b);
            $display($time, " [gbf_controller] wgt_r_data1b : %h", u_gbf_pe_array.wire_wgt_r_data1b);
            $display($time, " [gbf_controller] wgt_r_data2b: %h", u_gbf_pe_array.wire_wgt_r_data2b);
            $display($time, " [gbf_controller] wire_wgt_mux_gbf2rf : %h", u_gbf_pe_array.wire_wgt_mux_gbf2rf);
            $display($time, " [gbf_controller] wire_wgt_data : %h", u_gbf_pe_array.wire_wgt_data);
            $display($time, " [en_BRAM] wire_wgt_en : %h", u_gbf_pe_array.wire_wgt_en);
            $display($time, " [mux32_BRAM] wire_wgt_mux32_addr : %h", u_gbf_pe_array.wire_wgt_mux32_addr);
            $display($time, " [mux32_BRAM] wire_wgt_mux32_dob : %h", u_gbf_pe_array.wire_wgt_mux32_dob);
            $display($time, " [pe_array] wire_rf_wgt_w_addr : %h", u_gbf_pe_array.wire_rf_wgt_w_addr);
            $display($time, " [pe_array] wire_rf_wgt_buf1_send_finish : %h", u_gbf_pe_array.wire_rf_wgt_buf1_send_finish);
            $display($time, " [pe_array] wire_rf_wgt_buf2_send_finish : %h", u_gbf_pe_array.wire_rf_wgt_buf2_send_finish);
            $display($time, " [gbf_controller] wgt_rf_num : %h", u_gbf_pe_array.u_gbf_controller_new.wgt_rf_num);
            $display($time, " [pe_array] wire_wgt_rf1_need_data : %h", u_gbf_pe_array.wire_wgt_rf1_need_data);
            $display($time, " [pe_array] wire_wgt_rf2_need_data : %h", u_gbf_pe_array.wire_wgt_rf2_need_data);
            $display($time, " [gbf_controller] actv_en1b : %h", u_gbf_pe_array.wire_actv_en1b);
            $display($time, " [gbf_controller] actv_addr1b : %h", u_gbf_pe_array.wire_actv_addr1b);
            $display($time, " [gbf_controller] actv_r_data1b : %h", u_gbf_pe_array.wire_actv_r_data1b);
            $display($time, " [gbf_controller] actv_r_data2b: %h", u_gbf_pe_array.wire_actv_r_data2b);
            $display($time, " [gbf_controller] wire_actv_mux_gbf2rf : %h", u_gbf_pe_array.wire_actv_mux_gbf2rf);
            $display($time, " [gbf_controller] wire_actv_data : %h", u_gbf_pe_array.wire_actv_data);
            $display($time, " [en_BRAM] wire_actv_en : %h", u_gbf_pe_array.wire_actv_en);
            $display($time, " [mux32_BRAM] wire_actv_mux32_addr : %h", u_gbf_pe_array.wire_actv_mux32_addr);
            $display($time, " [mux32_BRAM] wire_actv_mux32_dob : %h", u_gbf_pe_array.wire_actv_mux32_dob);
            $display($time, " [pe_array] wire_rf_actv_w_addr : %h", u_gbf_pe_array.wire_rf_actv_w_addr);
            $display($time, " [pe_array] wire_rf_actv_buf1_send_finish : %h", u_gbf_pe_array.wire_rf_actv_buf1_send_finish);
            $display($time, " [pe_array] wire_rf_actv_buf2_send_finish : %h", u_gbf_pe_array.wire_rf_actv_buf2_send_finish);
            $display($time, " [gbf_controller] actv_rf_num : %h", u_gbf_pe_array.u_gbf_controller_new.actv_rf_num);
            $display($time, " [pe_array] wire_actv_rf1_need_data : %h", u_gbf_pe_array.wire_actv_rf1_need_data);
            $display($time, " [pe_array] wire_actv_rf2_need_data : %h", u_gbf_pe_array.wire_actv_rf2_need_data);
        end

        
    end

endmodule