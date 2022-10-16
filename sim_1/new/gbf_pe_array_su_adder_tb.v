//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_tb
// Description:
//		testbench for gbf_pe_array_su_adder
//      
//      
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module gbf_pe_array_su_adder_tb ();
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
    //input for actv/wgt gbf buffer
    reg actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a;
    reg [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a;
    reg [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a;
    //input for gbf_controller
    reg finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;
    //output of gbf_controller
    wire actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data;
    //output for psum_gbf
    wire [GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_gbf_w_en;
    wire [4:0] psum_gbf_w_addr;
    wire psum_gbf_w_num;
    wire psum_gbf_r_en;
    wire [4:0] psum_gbf_r_addr;
    wire psum_gbf_w_en_for_init;
    wire [4:0] psum_gbf_w_addr_for_init;

    gbf_pe_array_su_adder #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)) u_gbf_pe_array_su_adder(
    .clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num), .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init));

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
            $display($time, " [pe_array] wire_psum_1 : %h", u_gbf_pe_array_su_adder.u_gbf_pe_array.u_pe_array_w_controller.pe_array.wire_psum1);
            $display($time, " [pe_array] wire_psum_2 : %h", u_gbf_pe_array_su_adder.u_gbf_pe_array.u_pe_array_w_controller.pe_array.wire_psum2);
            $display($time, " [gbf_pe_array_su_adder] w_addr_from_su_adder : %d", u_gbf_pe_array_su_adder.w_addr_from_su_adder);
        end

        
    end

endmodule