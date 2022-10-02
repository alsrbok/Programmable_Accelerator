//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: rel_mem_accumulator_tb
// Description:
//		testbench for rel_mem_accumulator

//  
// History: 2022.09.26 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module rel_mem_accumulator_tb();
    parameter ROW                   = 16;
    parameter COL                   = 16;
    parameter DATA_BITWIDTH         = 16;
    parameter GBF_DATA_BITWIDTH     = 512;
    parameter PSUM_RF_ADDR_BITWIDTH = 2;
    parameter DEPTH                 = 32;
              
    reg clk, reset;
    reg [DATA_BITWIDTH*ROW*COL-1:0] psum_out;
    reg pe_psum_finish, conv_finish;
    wire [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr;
    wire su_add_finish;
    wire [GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_write_en;
    wire [9:0] psum_BRAM_addr;

    rel_mem_accumulator #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_rel_mem_accumulator(.clk(clk), .reset(reset), .psum_out(psum_out), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .psum_rf_addr(psum_rf_addr),
    .su_add_finish(su_add_finish), .out_data(out_data), .psum_write_en(psum_write_en), .psum_BRAM_addr(psum_BRAM_addr));

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;

        #10 reset = 0; pe_psum_finish = 1'b0;

        #50
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
        #10
        pe_psum_finish = 1'b1;

        //Timing issue between rf_addr should be considered later.
    end

endmodule