//------------------------------------------------------------+
// Project: Spatial Accelerator
// Module: pe_array_w_controller_tb
// Description:
//		testbench for pe_array_w_controller
//      
//      
//
// History: 2022.08.31 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps


module pe_array_w_controller_tb();

    parameter ROW                   = 16;
    parameter COL                   = 16;
    parameter IN_BITWIDTH           = 16;
    parameter OUT_BITWIDTH          = 16;
    parameter ACTV_ADDR_BITWIDTH    = 2;
    parameter ACTV_DEPTH            = 4;
    parameter WGT_ADDR_BITWIDTH     = 2;
    parameter WGT_DEPTH             = 4;
    parameter PSUM_ADDR_BITWIDTH    = 2;
    parameter PSUM_DEPTH            = 4;
    parameter DATA_BITWIDTH         = 512;

    reg clk, reset, finish;
    reg actv_data_avail, wgt_data_avail, actv_buf1_send_finish, actv_buf2_send_finish, wgt_buf1_send_finish, wgt_buf2_send_finish;
    reg su_add_finish;
    reg [ROW*COL-1:0] actv_en; reg [ACTV_ADDR_BITWIDTH-1:0] actv_w_addr; reg [DATA_BITWIDTH-1:0] actv_data; reg [5*ROW*COL-1 : 0] actv_mux32_sel;
    reg [ROW*COL-1:0] wgt_en; reg [WGT_ADDR_BITWIDTH-1:0] wgt_w_addr; reg [DATA_BITWIDTH-1:0] wgt_data; reg [5*ROW*COL-1 : 0] wgt_mux32_sel;
    reg [PSUM_ADDR_BITWIDTH-1:0] addr_from_su_adder;
    wire actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data;
    wire pe_psum_finish;
    wire conv_finish;
    wire [OUT_BITWIDTH*ROW*COL-1:0] psum_out;
    wire turn_off;

    pe_array_w_controller #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH),
    .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH)) pe_array_w_controller(.clk(clk), .reset(reset), .finish(finish), .actv_data_avail(actv_data_avail), 
    .wgt_data_avail(wgt_data_avail), .actv_buf1_send_finish(actv_buf1_send_finish), .actv_buf2_send_finish(actv_buf2_send_finish), .wgt_buf1_send_finish(wgt_buf1_send_finish), .wgt_buf2_send_finish(wgt_buf2_send_finish), .su_add_finish(su_add_finish), 
    .actv_en(actv_en), .actv_w_addr(actv_w_addr), .actv_data(actv_data), .actv_mux32_sel(actv_mux32_sel), .wgt_en(wgt_en), .wgt_w_addr(wgt_w_addr), .wgt_data(wgt_data), .wgt_mux32_sel(wgt_mux32_sel), 
    .addr_from_su_adder(addr_from_su_adder), .actv_rf1_need_data(actv_rf1_need_data), .actv_rf2_need_data(actv_rf2_need_data), .wgt_rf1_need_data(wgt_rf1_need_data), .wgt_rf2_need_data(wgt_rf2_need_data),
    .pe_psum_finish(pe_psum_finish), .conv_finish(conv_finish), .psum_out(psum_out), .turn_off(turn_off));

    always
        #5 clk = ~clk;

    initial begin
        clk = 0;
        //IDLE state
        reset = 0;

        #10 reset = 1;
        #10 reset = 0;
        //S1 state : actv_data_avail become 1
        #10 actv_data_avail = 1'b1; //use negedge to ensure the stability.

        //tm=0 for actv
        #10 // 1cycle is required for sending actv_sel signal to pe_array (from controller)
        actv_w_addr = 2'b00;    actv_data = {16'd1, 16'd2, 16'd3, 16'd4, 16'd5, 16'd6, 16'd7, 16'd8, 16'd9, 16'd10, 16'd11, 16'd12, 16'd13, 16'd14, 16'd15, 16'd16,
        16'd17, 16'd18, 16'd19, 16'd20, 16'd21, 16'd22, 16'd23, 16'd24, 16'd25, 16'd26, 16'd27, 16'd28, 16'd29, 16'd30, 16'd31, 16'd32};
        actv_en = {128'b0, 32'b0, {32{1'b1}}, 32'b0, {32{1'b1}}}; actv_mux32_sel = {640'd0, {2{160'd0, 5'd31, 5'd30, 5'd29, 5'd28, 5'd27, 5'd26, 5'd25, 5'd24, 5'd23, 5'd22, 5'd21, 5'd20,
        5'd19, 5'd18, 5'd17, 5'd16, 5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0}}};

        #10 //gbf_controller should send signals and address at negedge clk
        wgt_data_avail = 1'b1;
        actv_data = {16'd33, 16'd34, 16'd35, 16'd36, 16'd37, 16'd38, 16'd39, 16'd40, 16'd41, 16'd42, 16'd43, 16'd44, 16'd45, 16'd46, 16'd47, 16'd48,
        16'd49, 16'd50, 16'd51, 16'd52, 16'd53, 16'd54, 16'd55, 16'd56, 16'd57, 16'd58, 16'd59, 16'd60, 16'd61, 16'd62, 16'd63, 16'd64};
        actv_en = {128'b0, {32{1'b1}}, 32'b0, {32{1'b1}}, 32'b0}; actv_mux32_sel = {640'd0, {2{5'd31, 5'd30, 5'd29, 5'd28, 5'd27, 5'd26, 5'd25, 5'd24, 5'd23, 5'd22, 5'd21, 5'd20,
        5'd19, 5'd18, 5'd17, 5'd16, 5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0, 160'd0}}};

        #10 //tm=0 for wgt: all pe use wgt=1
        actv_data = {16'd65, 16'd66, 16'd67, 16'd68, 16'd69, 16'd70, 16'd71, 16'd72, 16'd73, 16'd74, 16'd75, 16'd76, 16'd77, 16'd78, 16'd79, 16'd80,
        16'd81, 16'd82, 16'd83, 16'd84, 16'd85, 16'd86, 16'd87, 16'd88, 16'd89, 16'd90, 16'd91, 16'd92, 16'd93, 16'd94, 16'd95, 16'd96};
        actv_en = {32'b0, {32{1'b1}}, 32'b0, {32{1'b1}}, 128'b0}; actv_mux32_sel = {{2{160'd0, 5'd31, 5'd30, 5'd29, 5'd28, 5'd27, 5'd26, 5'd25, 5'd24, 5'd23, 5'd22, 5'd21, 5'd20,
        5'd19, 5'd18, 5'd17, 5'd16, 5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0}}, 640'd0};

        wgt_w_addr = 2'b00; wgt_data = {{31{16'd2}}, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd31}};

        //tm=1 for wgt: all pe use wgt=3
        #10
        actv_data = {16'd97, 16'd98, 16'd99, 16'd100, 16'd101, 16'd102, 16'd103, 16'd104, 16'd105, 16'd106, 16'd107, 16'd108, 16'd109, 16'd110, 16'd111, 16'd112,
        16'd113, 16'd114, 16'd115, 16'd116, 16'd117, 16'd118, 16'd119, 16'd120, 16'd121, 16'd122, 16'd123, 16'd124, 16'd125, 16'd126, 16'd127, 16'd128};
        actv_en = {{32{1'b1}}, 32'b0, {32{1'b1}}, 32'b0, 128'b0}; actv_mux32_sel = {{2{5'd31, 5'd30, 5'd29, 5'd28, 5'd27, 5'd26, 5'd25, 5'd24, 5'd23, 5'd22, 5'd21, 5'd20,
        5'd19, 5'd18, 5'd17, 5'd16, 5'd15, 5'd14, 5'd13, 5'd12, 5'd11, 5'd10, 5'd9, 5'd8, 5'd7, 5'd6, 5'd5, 5'd4, 5'd3, 5'd2, 5'd1, 5'd0, 160'd0}}, 640'd0};

        wgt_w_addr = 2'b01; wgt_data = {{30{16'd3}}, 16'd2, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd29}};


        //tm=1 for actv: all pe use actv=1 && tm=2 for wgt: all pe use wgt=2
        #10
        actv_w_addr = 2'b01;  actv_data = {{31{16'd2}}, 16'd1}; actv_en = {256{1'b1}}; actv_mux32_sel ={256{5'd31}};
        wgt_w_addr = 2'b10; wgt_data = {{30{16'd3}}, 16'd2, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd30}};


        //tm=2 for actv: all pe use actv=2 && tm=3 for wgt: all pe use wgt=1
        #10
        actv_w_addr = 2'b10;  actv_data = {{30{16'd3}}, 16'd2, 16'd1}; actv_en = {256{1'b1}}; actv_mux32_sel ={256{5'd30}};
        wgt_w_addr = 2'b11; wgt_data = {{30{16'd3}}, 16'd2, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd31}};

        //tm=3 for actv: all pe use actv=1
        #10
        actv_w_addr = 2'b11;  actv_data = {{29{16'd3}}, 16'd1, 16'd2, 16'd1}; actv_en = {256{1'b1}}; actv_mux32_sel ={256{5'd29}};
        wgt_buf1_send_finish = 1'b1; wgt_en = {256'b0};

        #10
        actv_buf1_send_finish = 1'b1; actv_en = {256'b0};

        #10 //:110,000ns / 1 cycle is additionally required to send MAC_en signal to each PE (from controller)
        wgt_buf1_send_finish = 1'b0; actv_buf1_send_finish = 1'b0; //:Change send_finish signal to zero

        #10 //another 1cycle delay.. what happens?

        #10 //$display("%0t ns Calculate Start ", $time);

        //tm=0 data for buffer2 (gbf controller only sends wgt_en.. not a actv_en!!)
        #30
        wgt_w_addr = 2'b00; wgt_data = {{31{16'd2}}, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd30}};

        #10 // t=170,000ns (It will be write at posedge clk: 175,000ns)
        wgt_w_addr = 2'b01; wgt_data = {{30{16'd3}}, 16'd2, 16'd1}; wgt_mux32_sel ={256{5'd29}};

        #10 // t=180,000ns (It will be write at posedge clk: 185,000ns)
        wgt_w_addr = 2'b10; wgt_data = {{30{16'd3}}, 16'd4, 16'd1};  wgt_mux32_sel ={256{5'd30}};


        #10 // t=190,000ns (It will be write at posedge clk: 195,000ns), at 195,000ns S2 state is finished
        wgt_w_addr = 2'b11;  wgt_data = {{29{16'd3}}, 16'd1, 16'd2, 16'd5};  wgt_mux32_sel ={256{5'd31}};

        #10 // t=200,000ns (nxt_state is changed init_S3 since wgt_flag, psum_flag is on at this time)
        wgt_buf2_send_finish = 1'b1; wgt_en = {256{1'b0}}; su_add_finish = 1'b1; //gbf controller should send su_add_finish initially. (buf2 is not used yet.)
        
        #10 // t=210,000ns (controller set turn_off = 1'b1 since it enter to the init_S3 state)
        //t=215,000ns first posedge clk with delay_S3 state, in order to deal with the delay of sending data

        #10 // t=220,000ns (gbf_controller and su_adder get turn_off signal at 215,000ns and turn finish signal off at this time)
        wgt_buf2_send_finish = 1'b0;  su_add_finish = 1'b0;

        #10 // t=230,000ns, set nxt_state to S3

        #90 // t=310,000ns, MAC operation end at 315,000ns
        
        #10 // t=330,000ns, tm=0 for wgt rf buffer 1
        wgt_w_addr = 2'b00; wgt_data = {{31{16'd2}}, 16'd1}; wgt_en = {256{1'b1}}; wgt_mux32_sel ={256{5'd30}};

        #10 // t=340,000ns, tm=1 for wgt rf buffer 1
        wgt_w_addr = 2'b01; wgt_data = {{30{16'd3}}, 16'd2, 16'd1}; wgt_mux32_sel ={256{5'd29}};

        #10 // t=350,000ns, tm=2 for wgt rf buffer 1
        wgt_w_addr = 2'b10; wgt_data = {{30{16'd3}}, 16'd4, 16'd1}; wgt_mux32_sel ={256{5'd30}};

        #10 // t=360,000ns, tm=3 for wgt rf buffer 1
        wgt_w_addr = 2'b11;  wgt_data = {{29{16'd3}}, 16'd1, 16'd2, 16'd5};  wgt_mux32_sel ={256{5'd31}};

        #10 // t=370,000ns, wgt send finish but do not change the state to init_S3 (because psum buffer is not ready)
        wgt_buf2_send_finish = 1'b1; wgt_en = {256{1'b0}};

        #20 // t=390,000ns, nxt_state = init_S3
        su_add_finish = 1'b1;

        #10 // t=400,000ns, (controller set turn_off = 1'b1 since it enter to the init_S3 state)

        #10 // t=410,000ns (gbf_controller and su_adder get turn_off signal at 405,000ns and turn finish signal off at this time)
        wgt_buf2_send_finish = 1'b0;  su_add_finish = 1'b0;

        #100 // t=500,000ns, MAC operation end at 505,000ns
            ;

        //$stop;
    end

endmodule
