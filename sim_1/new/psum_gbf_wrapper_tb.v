//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: psum_gbf_wrapper_tb
// Description:
//		testbench for psum_gbf_wrapper
//      
//      
//  
// History: 2022.10.15 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module psum_gbf_wrapper_tb ();
    parameter ROW                   = 16;
    parameter COL                   = 16;
    parameter OUT_BITWIDTH          = 16;
    parameter PSUM_GBF_DATA_BITWIDTH     = 512;
    parameter PSUM_GBF_ADDR_BITWIDTH     = 5;
    parameter PSUM_GBF_DEPTH             = 32;
    reg clk;
    reg [PSUM_GBF_DATA_BITWIDTH-1:0] out_data;
    reg psum_gbf_w_en;
    reg [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr;
    reg psum_gbf_w_num;
    reg psum_gbf_r_en;
    reg [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_r_addr;
    reg psum_gbf_w_en_for_init;
    reg [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr_for_init;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b_out;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data2b_out;
    wire r_en1b_out, r_en2b_out;

    psum_gbf_wrapper #(.ROW(ROW), .COL(COL), .OUT_BITWIDTH(OUT_BITWIDTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)
    ) u_psum_gbf_wrapper(.clk(clk), .out_data(out_data), .psum_gbf_w_en(psum_gbf_w_en), .psum_gbf_w_addr(psum_gbf_w_addr), .psum_gbf_w_num(psum_gbf_w_num), .psum_gbf_r_en(psum_gbf_r_en), .psum_gbf_r_addr(psum_gbf_r_addr), .psum_gbf_w_en_for_init(psum_gbf_w_en_for_init), .psum_gbf_w_addr_for_init(psum_gbf_w_addr_for_init),
    .r_data1b_out(r_data1b), .r_data2b_out(r_data2b), .r_en1b_out(r_en1b_out), .r_en2b_out(r_en2b_out));

    always
        #5 clk = ~clk;

    integer i;

    initial begin
        clk = 0; psum_gbf_w_en = 1'b0; psum_gbf_w_num = 1'b0; psum_gbf_r_en = 1'b0; psum_gbf_w_en_for_init = 1'b0;
        //IDLE state

        for(i=0; i<10; i=i+1) begin
            #20psum_gbf_w_en = 1'b1;
            #30 psum_gbf_w_en = 1'b0;
            #10 psum_gbf_w_en = 1'b1;
            #20 psum_gbf_w_en = 1'b0;
        end
        psum_gbf_w_num = 1'b1;

        #20
        psum_gbf_w_en = 1'b1; psum_gbf_r_en = 1'b1;

        #60
        psum_gbf_r_en = 1'b0; psum_gbf_w_en_for_init = 1'b1;

        #50
        psum_gbf_w_en_for_init = 1'b0;

        #100
        $finish;
    end

endmodule