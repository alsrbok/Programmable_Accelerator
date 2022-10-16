//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: gbf_pe_array
// Description:
//		actv/wgt_gbf + gbf_controller_new + pe_array_w_controller
//      
//
// History: 2022.09.17 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module gbf_pe_array #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH     = 256,  //Data Bitwidth/Bandwith for actv/wgt gbf
            parameter GBF_ADDR_BITWIDTH     = 5,    //Addr Bitwidth for actv/wgt gbf
            parameter GBF_DEPTH             = 32 ) //Depth for actv/wgt gbf
        (   input clk, reset,
            //input for actv/wgt gbf buffer
            input actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a, 
            input [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a,
            input [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a,
            //input for gbf_controller
            input finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready,
            //input for actv/wgt_en_BRAM
            //input for actv/wgt_mux32_BRAM
            //input for pe_array_w_controller
            input [PSUM_ADDR_BITWIDTH-1:0] addr_from_su_adder,
            input su_add_finish,
            //output of gbf_controller
            output actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data,
            //output of pe_array_w_controller
            output pe_psum_finish, conv_finish, turn_off,
            output [OUT_BITWIDTH*ROW*COL-1:0] psum_out
            );
    
    //actv_gbf, wgt_gbf
    wire wire_actv_en1b, wire_actv_en2b, wire_wgt_en1b, wire_wgt_en2b;
    wire [GBF_ADDR_BITWIDTH-1:0] wire_actv_addr1b, wire_wgt_addr1b;
    wire [GBF_DATA_BITWIDTH-1:0] wire_actv_r_data1b, wire_actv_r_data2b, wire_wgt_r_data1b, wire_wgt_r_data2b;

     gbf_db #(.DATA_BITWIDTH(GBF_DATA_BITWIDTH), .ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .DEPTH(GBF_DEPTH), .MEM_INIT_FILE1("gbf_actv_buf1.mem"), .MEM_INIT_FILE2("gbf_actv_buf2.mem")
     ) actv_global_buffer(.clk(clk), .en1a(actv_en1a), .en1b(wire_actv_en1b), .we1a(actv_we1a), .en2a(actv_en2a), .en2b(wire_actv_en2b), .we2a(actv_we2a), .addr1a(actv_addr1a),
     .addr1b(wire_actv_addr1b), .addr2a(actv_addr2a), .addr2b(wire_actv_addr1b), .w_data1a(actv_w_data1a), .w_data2a(actv_w_data2a), .r_data1b(wire_actv_r_data1b), .r_data2b(wire_actv_r_data2b));

     gbf_db #(.DATA_BITWIDTH(GBF_DATA_BITWIDTH), .ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .DEPTH(GBF_DEPTH), .MEM_INIT_FILE1("gbf_wgt_buf1.mem"), .MEM_INIT_FILE2("gbf_wgt_buf2.mem")
     ) wgt_global_buffer(.clk(clk), .en1a(wgt_en1a), .en1b(wire_wgt_en1b), .we1a(wgt_we1a), .en2a(wgt_en2a), .en2b(wire_wgt_en2b), .we2a(wgt_we2a), .addr1a(wgt_addr1a),
     .addr1b(wire_wgt_addr1b), .addr2a(wgt_addr2a), .addr2b(wire_wgt_addr1b), .w_data1a(wgt_w_data1a), .w_data2a(wgt_w_data2a), .r_data1b(wire_wgt_r_data1b), .r_data2b(wire_wgt_r_data2b));

    //gbf_controller
    wire wire_actv_rf1_need_data, wire_actv_rf2_need_data, wire_wgt_rf1_need_data, wire_wgt_rf2_need_data;
    wire wire_actv_mux_gbf2rf, wire_wgt_mux_gbf2rf;
    wire [2:0] wire_actv_mux32_addr, wire_wgt_mux32_addr;
    wire wire_actv_rf_end_out, wire_wgt_rf_end_out;
    wire [2:0] wire_rf_actv_en_addr, wire_rf_wgt_en_addr;
    wire [ACTV_ADDR_BITWIDTH-1:0] wire_rf_actv_w_addr; wire [WGT_ADDR_BITWIDTH-1:0] wire_rf_wgt_w_addr;
    wire wire_rf_actv_data_avail, wire_rf_wgt_data_avail, wire_rf_actv_buf1_send_finish,  wire_rf_actv_buf2_send_finish, wire_rf_buf1_wgt_send_finish, wire_rf_buf2_wgt_send_finish;
    wire wire_conv_finish;

    gbf_controller_new #(.ROW(ROW), .COL(COL), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), 
    .GBF_DEPTH(GBF_DEPTH)) u_gbf_controller_new(.clk(clk), .reset(reset), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail), .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), 
    .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .actv_rf1_need_data(wire_actv_rf1_need_data), .actv_rf2_need_data(wire_actv_rf2_need_data), .wgt_rf1_need_data(wire_wgt_rf1_need_data), .wgt_rf2_need_data(wire_wgt_rf2_need_data), .actv_gbf_addrb(wire_actv_addr1b), .wgt_gbf_addrb(wire_wgt_addr1b),
    .actv_gbf_en1b(wire_actv_en1b), .actv_gbf_en2b(wire_actv_en2b), .wgt_gbf_en1b(wire_wgt_en1b), .wgt_gbf_en2b(wire_wgt_en2b), .actv_mux_gbf2rf(wire_actv_mux_gbf2rf), .wgt_mux_gbf2rf(wire_wgt_mux_gbf2rf), .actv_mux32_addr(wire_actv_mux32_addr), .wgt_mux32_addr(wire_wgt_mux32_addr),
    .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data), .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .actv_rf_end_out(wire_actv_rf_end_out), .wgt_rf_end_out(wire_wgt_rf_end_out), .rf_actv_en_addr(wire_rf_actv_en_addr), .rf_wgt_en_addr(wire_rf_wgt_en_addr),
    .rf_actv_w_addr(wire_rf_actv_w_addr), .rf_wgt_w_addr(wire_rf_wgt_w_addr), .rf_actv_data_avail(wire_rf_actv_data_avail), .rf_wgt_data_avail(wire_rf_wgt_data_avail), .rf_actv_buf1_send_finish(wire_rf_actv_buf1_send_finish), .rf_actv_buf2_send_finish(wire_rf_actv_buf2_send_finish), .rf_wgt_buf1_send_finish(wire_rf_wgt_buf1_send_finish), .rf_wgt_buf2_send_finish(wire_rf_wgt_buf2_send_finish), .conv_finish(wire_conv_finish)
    );

    wire [GBF_DATA_BITWIDTH-1:0] wire_actv_data, wire_wgt_data;

    mux2 #(.WIDTH(GBF_DATA_BITWIDTH)) actv_gbf_to_rf(.zero(wire_actv_r_data1b), .one(wire_actv_r_data2b), .sel(wire_actv_mux_gbf2rf), .out(wire_actv_data));
    mux2 #(.WIDTH(GBF_DATA_BITWIDTH)) wgt_gbf_to_rf(.zero(wire_wgt_r_data1b), .one(wire_wgt_r_data2b), .sel(wire_wgt_mux_gbf2rf), .out(wire_wgt_data));

    //en_BRAM
    wire [ROW*COL-1:0] wire_actv_en_dob, wire_wgt_en_dob;
    wire [ROW*COL-1:0] wire_actv_en, wire_wgt_en;

    simple_dp_ram #(.DATA_BITWIDTH(256), .ADDR_BITWIDTH(3), .DEPTH(8), .MEM_INIT_FILE("rf_actv_en.mem")
    ) u_actv_en_BRAM(.clk(clk), .ena(), .enb(~wire_actv_rf_end_out), .wea(), .addra(), .addrb(wire_rf_actv_en_addr), .dia(), .dob(wire_actv_en_dob));
    mux2 #(.WIDTH(256)) actv_en_BRAM_to_pe(.zero(wire_actv_en_dob), .one(256'b0), .sel(wire_actv_rf_end_out), .out(wire_actv_en));

    simple_dp_ram #(.DATA_BITWIDTH(256), .ADDR_BITWIDTH(3), .DEPTH(8), .MEM_INIT_FILE("rf_wgt_en.mem")
    ) u_wgt_en_BRAM(.clk(clk), .ena(), .enb(~wire_wgt_rf_end_out), .wea(), .addra(), .addrb(wire_rf_wgt_en_addr), .dia(), .dob(wire_wgt_en_dob));
    mux2 #(.WIDTH(256)) wgt_en_BRAM_to_pe(.zero(wire_wgt_en_dob), .one(256'b0), .sel(wire_wgt_rf_end_out), .out(wire_wgt_en));

    //mux32_BRAM
    wire [5*ROW*COL-1:0] wire_actv_mux32_dob, wire_wgt_mux32_dob;
    simple_dp_ram #(.DATA_BITWIDTH(5*ROW*COL), .ADDR_BITWIDTH(3), .DEPTH(8), .MEM_INIT_FILE("rf_actv_mux32.mem")
    ) u_actv_mux32_BRAM(.clk(clk), .ena(), .enb(~wire_actv_rf_end_out), .wea(), .addra(), .addrb(wire_actv_mux32_addr), .dia(), .dob(wire_actv_mux32_dob));

    simple_dp_ram #(.DATA_BITWIDTH(5*ROW*COL), .ADDR_BITWIDTH(3), .DEPTH(8), .MEM_INIT_FILE("rf_wgt_mux32.mem")
    ) u_wgt_mux32_BRAM(.clk(clk), .ena(), .enb(~wire_wgt_rf_end_out), .wea(), .addra(), .addrb(wire_wgt_mux32_addr), .dia(), .dob(wire_wgt_mux32_dob));

    //pe_array_w_controller
    pe_array_w_controller #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH)
    ) u_pe_array_w_controller(.clk(clk), .reset(reset), .finish(wire_conv_finish), .actv_data_avail(wire_rf_actv_data_avail), .wgt_data_avail(wire_rf_wgt_data_avail), .actv_buf1_send_finish(wire_rf_actv_buf1_send_finish), .actv_buf2_send_finish(wire_rf_actv_buf2_send_finish), .wgt_buf1_send_finish(wire_rf_wgt_buf1_send_finish), .wgt_buf2_send_finish(wire_rf_wgt_buf2_send_finish), .su_add_finish(su_add_finish), .actv_en(wire_actv_en), .wgt_en(wire_wgt_en),
    .actv_w_addr(wire_rf_actv_w_addr), .wgt_w_addr(wire_rf_wgt_w_addr), .actv_data(wire_actv_data), .wgt_data(wire_wgt_data), .actv_mux32_sel(wire_actv_mux32_dob), .wgt_mux32_sel(wire_wgt_mux32_dob), .addr_from_su_adder(addr_from_su_adder), .actv_rf1_need_data(wire_actv_rf1_need_data), .actv_rf2_need_data(wire_actv_rf2_need_data), 
    .wgt_rf1_need_data(wire_wgt_rf1_need_data), .wgt_rf2_need_data(wire_wgt_rf2_need_data), .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .psum_out(psum_out), .turn_off(turn_off));


endmodule