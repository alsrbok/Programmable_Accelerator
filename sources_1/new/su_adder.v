//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder
// Description:
//		It contains rel_mem_accumulator, su_adder_v1, su_adder_for_ambi_irrel
//      
//      
//  
// History: 2022.10.02 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module su_adder #(parameter ROW                   = 16,
                parameter COL                   = 16,
                parameter DATA_BITWIDTH         = 16,
                parameter GBF_DATA_BITWIDTH     = 512,
                parameter PSUM_RF_ADDR_BITWIDTH    = 2,
                parameter DEPTH                 = 32)
              ( input clk, reset, 
                input [DATA_BITWIDTH*ROW*COL-1:0] psum_out,
                input pe_psum_finish, conv_finish,
                output [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr,    //psum address whose data will be used in this module (output for gbf_pe_array)
                output su_add_finish,                               //output for gbf_pe_array
                output [GBF_DATA_BITWIDTH-1:0] out_data,            //output for psum_gbf
                output psum_write_en,                               //output for psum_gbf
                output [9:0] psum_BRAM_addr);                           //output for psum_gbf
    
    /*META-DATA*/
    reg [1:0] mode[0:1];            //mode 0: use rel_mem_accumulator, mode 1: use su_adder_v1, mode 2: use su_adder_for_ambi_irrel, dummy [1]
    reg [4:0] irrel_rel_num[0:1];   // [0]: irrel_num, [1]: rel_num

    always @(posedge reset) begin
        if(reset) begin
            $display("intialize the meta data for su_adder ");
            $readmemh("mode.mem", mode);
            $readmemh("irrel_rel_num.mem", irrel_rel_num);

            $display("check the initialization");
            $display("mode: [0]=%d", mode[0]);
            $display("irrel_rel_num: [0] [1]=%d %d", irrel_rel_num[0], irrel_rel_num[1]);
        end
    end

    wire w0_clk, w1_clk, w2_clk;
    wire w0_reset, w1_reset, w2_reset;

    wire [DATA_BITWIDTH*ROW*COL-1:0] w0_psum_out, w1_psum_out, w2_psum_out;
    wire [PSUM_RF_ADDR_BITWIDTH-1:0] w0_psum_rf_addr, w1_psum_rf_addr, w2_psum_rf_addr; 
    wire w0_su_add_finish, w1_su_add_finish, w2_su_add_finish;
    wire w0_pe_psum_finish, w1_pe_psum_finish, w2_pe_psum_finish;
    wire w0_conv_finish, w1_conv_finish, w2_conv_finish;

    demux4 #(.WIDTH(1)) clk_dmx(.in(clk), .sel(mode[0]), .out0(w0_clk), .out1(w1_clk), .out2(w2_clk), .out3());
    demux4 #(.WIDTH(1)) reset_dmx(.in(reset), .sel(mode[0]), .out0(w0_reset), .out1(w1_reset), .out2(w2_reset), .out3());

    demux4 #(.WIDTH(DATA_BITWIDTH*ROW*COL)) psum_out_dmx(.in(psum_out), .sel(mode[0]), .out0(w0_psum_out), .out1(w1_psum_out), .out2(w2_psum_out), .out3());
    mux4 #(.WIDTH(PSUM_RF_ADDR_BITWIDTH)) psum_rf_addr_mx(.in0(w0_psum_rf_addr), .in1(w1_psum_rf_addr), .in2(w2_psum_rf_addr), .in3(), .sel(mode[0]), .out(psum_rf_addr));
    mux4 #(.WIDTH(1)) su_add_finish_mx(.in0(w0_su_add_finish), .in1(w1_su_add_finish), .in2(w2_su_add_finish), .in3(), .sel(mode[0]), .out(su_add_finish));
    demux4 #(.WIDTH(1)) pe_psum_finish_dmx(.in(pe_psum_finish), .sel(mode[0]), .out0(w0_pe_psum_finish), .out1(w1_pe_psum_finish), .out2(w2_pe_psum_finish), .out3());
    demux4 #(.WIDTH(1)) conv_finish_dmx(.in(conv_finish), .sel(mode[0]), .out0(w0_conv_finish), .out1(w1_conv_finish), .out2(w2_conv_finish), .out3());

    rel_mem_accumulator #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_rel_mem_accumulator(.clk(w0_clk), .reset(w0_reset), .psum_out(w0_psum_out), .pe_psum_finish(w0_pe_psum_finish), .conv_finish(w0_conv_finish),
    .psum_rf_addr(w0_psum_rf_addr), .su_add_finish(w0_su_add_finish), .out_data(w0_out_data), .psum_write_en(w0_psum_write_en), .psum_BRAM_addr(w0_psum_BRAM_addr));

    su_adder_v1 #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder_v1(.clk(w1_clk), .reset(w1_reset), .psum_out(w1_psum_out), .pe_psum_finish(w1_pe_psum_finish), .conv_finish(w1_conv_finish), .irrel_num(irrel_rel_num[0]),
    .psum_rf_addr(w1_psum_rf_addr), .su_add_finish(w1_su_add_finish), .out_data(w1_out_data), .psum_write_en(w1_psum_write_en), .psum_BRAM_addr(w1_psum_BRAM_addr));

    su_adder_for_ambi_irrel #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder_for_ambi_irrel(.clk(w2_clk), .reset(w2_reset), .psum_out(w2_psum_out), .pe_psum_finish(w2_pe_psum_finish), .conv_finish(w2_conv_finish), .irrel_num(irrel_rel_num[0]), .rel_num(irrel_rel_num[1]),
    .psum_rf_addr(w2_psum_rf_addr), .su_add_finish(w2_su_add_finish), .out_data(w2_out_data), .psum_write_en(w2_psum_write_en), .psum_BRAM_addr(w2_psum_BRAM_addr));

    wire [GBF_DATA_BITWIDTH-1:0] w0_out_data, w1_out_data, w2_out_data;
    wire w0_psum_write_en, w1_psum_write_en, w2_psum_write_en;
    wire [9:0] w0_psum_BRAM_addr, w1_psum_BRAM_addr, w2_psum_BRAM_addr;

    mux4 #(.WIDTH(GBF_DATA_BITWIDTH)) out_data_mx(.in0(w0_out_data), .in1(w1_out_data), .in2(w2_out_data), .in3(), .sel(mode[0]), .out(out_data));
    mux4 #(.WIDTH(1)) psum_write_en_mx(.in0(w0_psum_write_en), .in1(w1_psum_write_en), .in2(w2_psum_write_en), .in3(), .sel(mode[0]), .out(psum_write_en));
    mux4 #(.WIDTH(10)) psum_BRAM_addr_mx(.in0(w0_psum_BRAM_addr), .in1(w1_psum_BRAM_addr), .in2(w2_psum_BRAM_addr), .in3(), .sel(mode[0]), .out(psum_BRAM_addr));

endmodule