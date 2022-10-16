//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: psum_gbf_wrapper
// Description:
//		It sends proper data and signals to psum_gbf
//      
//      
//  
// History: 2022.10.08 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module psum_gbf_wrapper #(parameter ROW         = 16,           //PE array row size
            parameter COL                   = 16,           //PE array column size
            parameter OUT_BITWIDTH          = 16,           //For psum
            parameter PSUM_GBF_DATA_BITWIDTH     = 512,
            parameter PSUM_GBF_ADDR_BITWIDTH     = 5,       //Addr Bitwidth for psum gbf
            parameter PSUM_GBF_DEPTH             = 32 )     //Depth for psum gbf :default = 2kB
        (   input clk,
            input [PSUM_GBF_DATA_BITWIDTH-1:0] out_data,                         //output data from su_adder
            input psum_gbf_w_en,                                            //write enable from su_adder
            input [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr,             //write address from su_adder
            input psum_gbf_w_num,                                           //currently, write data to psum_gbf buf 1(0) / 2(1)
            input psum_gbf_r_en,                                            //read enable from su_adder
            input [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_r_addr,             //read address from su_adder
            input psum_gbf_w_en_for_init,                                   //write enable in order to initialize the psum
            input [PSUM_GBF_ADDR_BITWIDTH-1:0] psum_gbf_w_addr_for_init,     //write address in order to initialize the psum
            output [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b_out,
            output [PSUM_GBF_DATA_BITWIDTH-1:0] r_data2b_out,
            output r_en1b_out, r_en2b_out);
    
    wire [PSUM_GBF_ADDR_BITWIDTH-1:0] w_addr1a, w_addr2a;
    wire en_we_1a, en_we_2a;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] w_data1a, w_data2a;
    wire [PSUM_GBF_ADDR_BITWIDTH-1:0] r_addr1b, r_addr2b;
    wire r_en1b, r_en2b;

    cross_demux2 #(.WIDTH(PSUM_GBF_ADDR_BITWIDTH)) w_addr_demux(.din0(psum_gbf_w_addr), .din1(psum_gbf_w_addr_for_init), .sel(psum_gbf_w_num), .dout0(w_addr1a), .dout1(w_addr2a));
    cross_demux2 #(.WIDTH(1)) enwe_demux(.din0(psum_gbf_w_en), .din1(psum_gbf_w_en_for_init), .sel(psum_gbf_w_num), .dout0(en_we_1a), .dout1(en_we_2a));
    cross_demux2 #(.WIDTH(PSUM_GBF_DATA_BITWIDTH)) w_data_demux(.din0(out_data), .din1(0), .sel(psum_gbf_w_num), .dout0(w_data1a), .dout1(w_data2a));
    cross_demux2 #(.WIDTH(PSUM_GBF_ADDR_BITWIDTH)) r_addr_demux(.din0(psum_gbf_r_addr), .din1(psum_gbf_w_addr), .sel(psum_gbf_w_num), .dout0(r_addr2b), .dout1(r_addr1b));
    cross_demux2 #(.WIDTH(1)) r_en_demux(.din0(psum_gbf_r_en), .din1(psum_gbf_w_en), .sel(psum_gbf_w_num), .dout0(r_en2b), .dout1(r_en1b));

    wire [PSUM_GBF_DATA_BITWIDTH-1:0] accum_data1a, accum_data2a;
    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b_for_add, r_data1b_from_gbf, r_data2b_for_add, r_data2b_from_gbf;

    demux2 #(.WIDTH(PSUM_GBF_DATA_BITWIDTH)) rdata1b_dmux(.d_in(r_data1b_from_gbf), .sel(psum_gbf_w_num), .zero(r_data1b_for_add), .one(r_data1b_out));
    demux2 #(.WIDTH(PSUM_GBF_DATA_BITWIDTH)) rdata2b_dmux(.d_in(r_data2b_from_gbf), .sel(psum_gbf_w_num), .zero(r_data2b_out), .one(r_data2b_for_add));

    assign accum_data1a = r_data1b_for_add + w_data1a;
    assign accum_data2a = r_data2b_for_add + w_data2a;

    gbf_db #(.DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .DEPTH(PSUM_GBF_DEPTH), .MEM_INIT_FILE1(""), .MEM_INIT_FILE2("")
    ) u_psum_gbf_db(.clk(clk), .en1a(en_we_1a), .en1b(r_en1b), .we1a(en_we_1a), .en2a(en_we_2a), .en2b(r_en2b), .we2a(en_we_2a), .addr1a(w_addr1a), .addr1b(r_addr1b),
    .addr2a(w_addr2a), .addr2b(r_addr2b), .w_data1a(accum_data1a), .w_data2a(accum_data2a), .r_data1b(r_data1b_from_gbf), .r_data2b(r_data2b_from_gbf));

    mux2 #(.WIDTH(1)) r_en1b_mx(.zero(0), .one(r_en1b), .sel(psum_gbf_w_num), .out(r_en1b_out));
    mux2 #(.WIDTH(1)) r_en2b_mx(.zero(r_en2b), .one(0), .sel(psum_gbf_w_num), .out(r_en2b_out));
    //assign r_en1b_out = psum_gbf_w_num ? 0 : r_en1b;
    //assign r_en2b_out = psum_gbf_w_num ? r_en2b : 0;
endmodule