//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: PE_new
// Description:
//		PE_new add psum_write_addr to support seperation of relation between read_addr and write_addr of psum on MAC
//
// History: 2022.08.15 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module PE_new #(parameter IN_BITWIDTH       = 8,  //For activation. weight
            parameter OUT_BITWIDTH          = 16,  //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,   //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4)
          ( input clk,
            input reset, input MAC_en, //enalbe signal for MAC from control logic
            input actv_en, actv_sel, input [ACTV_ADDR_BITWIDTH-1:0] actv_r_addr1, actv_w_addr1, actv_r_addr2, actv_w_addr2, input [IN_BITWIDTH-1:0] actv_data1, actv_data2,
            input wgt_en, wgt_sel, input [WGT_ADDR_BITWIDTH-1:0] wgt_r_addr1, wgt_w_addr1, wgt_r_addr2, wgt_w_addr2, input [IN_BITWIDTH-1:0] wgt_data1,wgt_data2,
            input psum_en, input [PSUM_ADDR_BITWIDTH-1:0] psum_addr1, psum_addr2, psum_write_addr, addr_from_su_adder,
            output [OUT_BITWIDTH-1:0] psum_out1, psum_out2
    );

    wire [IN_BITWIDTH-1:0] actv1, actv2, actv;
    wire [IN_BITWIDTH-1:0] wgt1, wgt2, wgt;
    wire [OUT_BITWIDTH-1:0] psum_in1, psum_in2, psum_in;
    wire [OUT_BITWIDTH-1:0] psum1, psum2, psum;
    wire [PSUM_ADDR_BITWIDTH-1:0] w_addr, w_addr1, w_addr2;
    wire out_en;
    //with pipelined reg
    
    reg MAC_en_reg;
    reg actv_en_reg, actv_sel_reg; 
    reg [ACTV_ADDR_BITWIDTH-1:0] actv_r_addr1_reg, actv_w_addr1_reg, actv_r_addr2_reg, actv_w_addr2_reg;
    reg [IN_BITWIDTH-1:0] actv_data1_reg, actv_data2_reg;
    reg wgt_en_reg, wgt_sel_reg; 
    reg [WGT_ADDR_BITWIDTH-1:0] wgt_r_addr1_reg, wgt_w_addr1_reg, wgt_r_addr2_reg, wgt_w_addr2_reg;
    reg [IN_BITWIDTH-1:0] wgt_data1_reg, wgt_data2_reg;
    reg psum_en_reg;
    reg [PSUM_ADDR_BITWIDTH-1:0] psum_addr1_reg, psum_addr2_reg, psum_write_addr_reg;

    always @(negedge clk) begin
      MAC_en_reg<=MAC_en; actv_en_reg<=actv_en; actv_sel_reg<=actv_sel;
      actv_r_addr1_reg<=actv_r_addr1; actv_w_addr1_reg<=actv_w_addr1; actv_r_addr2_reg<=actv_r_addr2; actv_w_addr2_reg<=actv_w_addr2;
      actv_data1_reg<=actv_data1; actv_data2_reg<=actv_data2;
      wgt_en_reg<=wgt_en; wgt_sel_reg<=wgt_sel;
      wgt_r_addr1_reg<=wgt_r_addr1; wgt_w_addr1_reg<=wgt_w_addr1; wgt_r_addr2_reg<=wgt_r_addr2; wgt_w_addr2_reg<=wgt_w_addr2;
      wgt_data1_reg<=wgt_data1; wgt_data2_reg<=wgt_data2;
      psum_en_reg<=psum_en;
      psum_addr1_reg<=psum_addr1; psum_addr2_reg<=psum_addr2; psum_write_addr_reg<=psum_write_addr;
    end 

    //register file for activation
    rf_iw_sync_dpdb #(.DATA_BITWIDTH(IN_BITWIDTH), .ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .DEPTH(ACTV_DEPTH)
     ) rf_actv(.clk(clk), .reset(reset), .write_sel(actv_sel_reg), .write_en(actv_en_reg), .r_addr1(actv_r_addr1_reg), .w_addr1(actv_w_addr1_reg), .w_data1(actv_data1_reg), 
     .r_addr2(actv_r_addr2_reg), .w_addr2(actv_w_addr2_reg), .w_data2(actv_data2_reg), .r_data1(actv1), .r_data2(actv2));

    mux2 #(.WIDTH(IN_BITWIDTH)) actv_mux(.zero(actv1), .one(actv2), .sel(actv_sel_reg), .out(actv));

    //register file for weight
    rf_iw_sync_dpdb #(.DATA_BITWIDTH(IN_BITWIDTH), .ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .DEPTH(WGT_DEPTH)
     ) rf_wgt(.clk(clk), .reset(reset), .write_sel(wgt_sel_reg), .write_en(wgt_en_reg), .r_addr1(wgt_r_addr1_reg), .w_addr1(wgt_w_addr1_reg), .w_data1(wgt_data1_reg), 
     .r_addr2(wgt_r_addr2_reg), .w_addr2(wgt_w_addr2_reg), .w_data2(wgt_data2_reg), .r_data1(wgt1), .r_data2(wgt2));

    mux2 #(.WIDTH(IN_BITWIDTH)) wgt_mux(.zero(wgt1), .one(wgt2), .sel(wgt_sel_reg), .out(wgt));

    //register file for psum
    rf_psum_sync_dpdb_new #(.DATA_BITWIDTH(OUT_BITWIDTH), .ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .DEPTH(PSUM_DEPTH)
     ) rf_psum(.clk(clk), .reset(reset), .en1(psum_en_reg), .out_en(out_en), .addr1(psum_addr1_reg), .w_data1(psum1), .w_addr1(w_addr1),
     .addr2(psum_addr2_reg), .w_data2(psum2), .w_addr2(w_addr2), .addr_from_su_adder(addr_from_su_adder), .r_data1(psum_in1), .r_data2(psum_in2), .out1(psum_out1), .out2(psum_out2));

    mux2 #(.WIDTH(OUT_BITWIDTH)) psum_mux(.zero(psum_in2), .one(psum_in1), .sel(psum_en_reg), .out(psum_in));
    demux2 #(.WIDTH(OUT_BITWIDTH)) psum_demux(.d_in(psum), .sel(psum_en_reg), .zero(psum2), .one(psum1));
    demux2 #(.WIDTH(PSUM_ADDR_BITWIDTH)) w_addr_demux(.d_in(w_addr), .sel(psum_en_reg), .zero(w_addr2), .one(w_addr1));

    //MAC for PE
    MAC_new #(.IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), . PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH)) mac(.a_in(actv), .w_in(wgt), 
    .sum_in(psum_in), .psum_write_addr(psum_write_addr_reg), .en(MAC_en_reg), .clk(clk), .out(psum), .out_en(out_en), .write_addr(w_addr));
    
endmodule
