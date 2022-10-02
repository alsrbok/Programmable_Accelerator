//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_tb
// Description:
//		testbench for su_adder
//      
//      
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module su_adder_tb ();

    parameter ROW                       = 16;
    parameter COL                       = 16;
    parameter DATA_BITWIDTH             = 16;
    parameter GBF_DATA_BITWIDTH         = 512;
    parameter PSUM_RF_ADDR_BITWIDTH     = 2;
    parameter DEPTH                     = 32;

    reg clk, reset;
    reg [DATA_BITWIDTH*ROW*COL-1:0] psum_out;
    reg pe_psum_finish, conv_finish;
    reg [4:0] irrel_num;  
    reg [4:0] rel_num; 
    wire [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr;
    wire su_add_finish;
    wire [GBF_DATA_BITWIDTH-1:0] out_data;
    wire psum_write_en;
    wire [9:0] psum_BRAM_addr;

    su_adder #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder(.clk(clk), .reset(reset), .psum_out(psum_out), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish),
    .psum_rf_addr(psum_rf_addr), .su_add_finish(su_add_finish), .out_data(out_data), .psum_write_en(psum_write_en), .psum_BRAM_addr(psum_BRAM_addr));

    integer i;

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;

        #10 reset = 0; pe_psum_finish = 1'b0; irrel_num=5'd4; rel_num=5'd3;

        #50
        
        psum_out = {16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, //0010
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, //000f
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, //000e
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, //000d
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, //000c
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000b
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000a
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //0009
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, //0010
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, //000f
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, //000e
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, //000d
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, //000c
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000b
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, //000a
                    16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd1, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0, 16'd0}; //0009

        #10 // t=80,000ns
        pe_psum_finish = 1'b1;

        for(i=0; i<10; i=i+1) begin
        #10
        $display($time);
        $display("psum_out w0 : %h", u_su_adder.w0_psum_out);
        $display("psum_out w1 : %h", u_su_adder.w1_psum_out);
        $display("psum_out w2 : %h", u_su_adder.w2_psum_out);
        $display("out_data w0 : %h", u_su_adder.w0_out_data);
        $display("out_data w1 : %h", u_su_adder.w1_out_data);
        $display("out_data w2 : %h", u_su_adder.w2_out_data);
        end

        //#200 // t=280,000ns :end of calculation at irrel_num = 2
    end
    
endmodule