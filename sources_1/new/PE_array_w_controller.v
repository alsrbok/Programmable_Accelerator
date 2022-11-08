//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: pe_array_w_controller
// Description:
//		PE array + PE array controller
//      It gets several signals and address from actv_wgt_gbf_controller(To Do..)
//      It communicates with psum_su_adder. (To Do..)
//
// History: 2022.08.31 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module pe_array_w_controller #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight, partial psum
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH         = 512)
          ( input clk, reset, finish,
            input actv_data_avail, wgt_data_avail, actv_buf1_send_finish, actv_buf2_send_finish, wgt_buf1_send_finish, wgt_buf2_send_finish,
            input su_add_finish,
            input [ROW*COL-1:0] actv_en, input [ACTV_ADDR_BITWIDTH-1:0] actv_w_addr, input [GBF_DATA_BITWIDTH-1:0] actv_data, input [5*ROW*COL-1 : 0] actv_mux32_sel,
            input [ROW*COL-1:0] wgt_en, input [WGT_ADDR_BITWIDTH-1:0] wgt_w_addr, input [GBF_DATA_BITWIDTH-1:0] wgt_data, input [5*ROW*COL-1 : 0] wgt_mux32_sel,
            input [PSUM_ADDR_BITWIDTH-1:0] addr_from_su_adder,
            output actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data,
            output pe_psum_finish,
            output conv_finish,
            output [OUT_BITWIDTH*ROW*COL-1:0] psum_out,
            output turn_off     //send it to gbf_controller, su_adder to let them know when to turn off the finish signal
            );

    wire [ROW*COL-1:0] wire_MAC_en;
    wire wire_actv_sel; wire [ACTV_ADDR_BITWIDTH-1:0] wire_actv_r_addr1, wire_actv_r_addr2;
    wire wire_wgt_sel; wire [WGT_ADDR_BITWIDTH-1:0] wire_wgt_r_addr1, wire_wgt_r_addr2;
    wire wire_psum_en; wire [PSUM_ADDR_BITWIDTH-1:0] wire_psum_addr1, wire_psum_addr2, wire_psum_write_addr;

    /*reg for tolerate timing violation between gbf data and pe rf*/
    /*
    reg [ROW*COL-1:0] actv_en_reg, wgt_en_reg;
    reg [GBF_DATA_BITWIDTH-1:0] actv_data_reg, wgt_data_reg;
    reg [5*ROW*COL-1 : 0] actv_mux32_sel_reg, wgt_mux32_sel_reg;
    reg [ACTV_ADDR_BITWIDTH-1:0] actv_w_addr_reg;
    reg [WGT_ADDR_BITWIDTH-1:0] wgt_w_addr_reg;
    //from pe_array_controller
    reg [ROW*COL-1:0] reg_MAC_en;
    reg reg_actv_sel; reg [ACTV_ADDR_BITWIDTH-1:0] reg_actv_r_addr1, reg_actv_r_addr2;
    reg reg_wgt_sel; reg [WGT_ADDR_BITWIDTH-1:0] reg_wgt_r_addr1, reg_wgt_r_addr2;
    reg reg_psum_en; reg [PSUM_ADDR_BITWIDTH-1:0] reg_psum_addr1, reg_psum_addr2, reg_psum_write_addr;
    
    
    always @(negedge clk) begin
      actv_en_reg <= actv_en; wgt_en_reg <= wgt_en;
      actv_data_reg <= actv_data; wgt_data_reg <= wgt_data;
      actv_mux32_sel_reg <= actv_mux32_sel; wgt_mux32_sel_reg <= wgt_mux32_sel;
      actv_w_addr_reg <= actv_w_addr; wgt_w_addr_reg <= wgt_w_addr;
      //
      reg_MAC_en <= wire_MAC_en;
      reg_actv_sel <= wire_actv_sel; reg_actv_r_addr1 <= wire_actv_r_addr1; reg_actv_r_addr2 <= wire_actv_r_addr2;
      reg_wgt_sel <= wire_wgt_sel; reg_wgt_r_addr1 <= wire_wgt_r_addr1; reg_wgt_r_addr2 <= wire_wgt_r_addr2;
      reg_psum_en <= wire_psum_en; reg_psum_addr1 <= wire_psum_addr1; reg_psum_addr2 <= wire_psum_addr2; reg_psum_write_addr <= wire_psum_write_addr;
    end
    


    PE_new_array #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH),
    .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH)) pe_array(.clk(clk), .reset(reset),
    .MAC_en(reg_MAC_en), .actv_sel(reg_actv_sel), .actv_en(actv_en_reg), .actv_r_addr1(reg_actv_r_addr1), .actv_r_addr2(reg_actv_r_addr2), .actv_w_addr(actv_w_addr_reg),
    .actv_data(actv_data_reg), .actv_mux32_sel(actv_mux32_sel_reg), .wgt_sel(reg_wgt_sel), .wgt_en(wgt_en_reg), .wgt_r_addr1(reg_wgt_r_addr1), .wgt_r_addr2(reg_wgt_r_addr2), .wgt_w_addr(wgt_w_addr_reg),
    .wgt_data(wgt_data_reg), .wgt_mux32_sel(wgt_mux32_sel_reg), .psum_en(reg_psum_en), .psum_addr1(reg_psum_addr1), .psum_addr2(reg_psum_addr2), .psum_write_addr(reg_psum_write_addr), 
    .addr_from_su_adder(addr_from_su_adder), .psum_out(psum_out));
    */

    //without pipelined register
    PE_new_array #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH),
    .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH)) pe_array(.clk(clk), .reset(reset),
    .MAC_en(wire_MAC_en), .actv_sel(wire_actv_sel), .actv_en(actv_en), .actv_r_addr1(wire_actv_r_addr1), .actv_r_addr2(wire_actv_r_addr2), .actv_w_addr(actv_w_addr),
    .actv_data(actv_data), .actv_mux32_sel(actv_mux32_sel), .wgt_sel(wire_wgt_sel), .wgt_en(wgt_en), .wgt_r_addr1(wire_wgt_r_addr1), .wgt_r_addr2(wire_wgt_r_addr2), .wgt_w_addr(wgt_w_addr),
    .wgt_data(wgt_data), .wgt_mux32_sel(wgt_mux32_sel), .psum_en(wire_psum_en), .psum_addr1(wire_psum_addr1), .psum_addr2(wire_psum_addr2), .psum_write_addr(wire_psum_write_addr), 
    .addr_from_su_adder(addr_from_su_adder), .psum_out(psum_out));

    pe_array_controller #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH),
    .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH)) controller(.clk(clk), .reset(reset), .finish(finish), .actv_data_avail(actv_data_avail), .wgt_data_avail(wgt_data_avail), 
    .actv_buf1_send_finish(actv_buf1_send_finish), .actv_buf2_send_finish(actv_buf2_send_finish), .wgt_buf1_send_finish(wgt_buf1_send_finish), .wgt_buf2_send_finish(wgt_buf2_send_finish), .su_add_finish(su_add_finish),
    .actv_rf1_need_data(actv_rf1_need_data), .actv_rf2_need_data(actv_rf2_need_data), .wgt_rf1_need_data(wgt_rf1_need_data), .wgt_rf2_need_data(wgt_rf2_need_data),
    .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .MAC_en(wire_MAC_en), .actv_sel(wire_actv_sel), .actv_r_addr1(wire_actv_r_addr1), .actv_r_addr2(wire_actv_r_addr2),
    .wgt_sel(wire_wgt_sel), .wgt_r_addr1(wire_wgt_r_addr1), .wgt_r_addr2(wire_wgt_r_addr2), .psum_en(wire_psum_en), .psum_addr1(wire_psum_addr1), .psum_addr2(wire_psum_addr2), 
    .psum_write_addr(wire_psum_write_addr), .turn_off(turn_off));


endmodule
