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
                parameter DATA_BITWIDTH         = 16,   //for psum
                parameter GBF_DATA_BITWIDTH     = 512,  //for psum_gbf
                parameter PSUM_RF_ADDR_BITWIDTH = 2,
                parameter GBF_ADDR_BITWIDTH     = 5,    //for psum_gbf
                parameter DEPTH                 = 32)   //for psum_gbf
              ( input clk, reset, 
                input [DATA_BITWIDTH*ROW*COL-1:0] psum_out,
                input pe_psum_finish, conv_finish,
                output [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr,    //psum address whose data will be used in this module (output for gbf_pe_array)
                output su_add_finish,                               //output for gbf_pe_array
                output [GBF_DATA_BITWIDTH-1:0] out_data,            //output data for psum_gbf
                output psum_gbf_w_en,                               //write enable for psum_gbf
                output [4:0] psum_gbf_w_addr,                       //write address for psum_gbf
                output psum_gbf_w_num,                              //currently, write data to psum_gbf buf 1(0) / 2(1)
                output reg psum_gbf_r_en,                               //read enable for psum_gbf
                output reg [4:0] psum_gbf_r_addr,                        //read address for psum_gbf
                output reg psum_gbf_w_en_for_init,                      //write enable in order to initialize the psum
                output reg [4:0] psum_gbf_w_addr_for_init);                //write address in order to initialize the psum
    
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

    wire [GBF_DATA_BITWIDTH-1:0] w0_out_data, w1_out_data, w2_out_data;
    wire w0_psum_gbf_w_en, w1_psum_gbf_w_en, w2_psum_gbf_w_en;
    wire [GBF_ADDR_BITWIDTH-1:0] w0_psum_gbf_w_addr, w1_psum_gbf_w_addr, w2_psum_gbf_w_addr;
    wire w0_psum_gbf_w_num, w1_psum_gbf_w_num, w2_psum_gbf_w_num;

    rel_mem_accumulator #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_rel_mem_accumulator(.clk(w0_clk), .reset(w0_reset), .psum_out(w0_psum_out), .pe_psum_finish(w0_pe_psum_finish), .conv_finish(w0_conv_finish),
    .psum_rf_addr(w0_psum_rf_addr), .su_add_finish(w0_su_add_finish), .out_data(w0_out_data), .psum_gbf_w_en(w0_psum_gbf_w_en), .psum_gbf_w_addr(w0_psum_gbf_w_addr), .psum_gbf_w_num(w0_psum_gbf_w_num));

    su_adder_v1 #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder_v1(.clk(w1_clk), .reset(w1_reset), .psum_out(w1_psum_out), .pe_psum_finish(w1_pe_psum_finish), .conv_finish(w1_conv_finish), .irrel_num(irrel_rel_num[0]),
    .psum_rf_addr(w1_psum_rf_addr), .su_add_finish(w1_su_add_finish), .out_data(w1_out_data), .psum_gbf_w_en(w1_psum_gbf_w_en), .psum_gbf_w_addr(w1_psum_gbf_w_addr), .psum_gbf_w_num(w1_psum_gbf_w_num));

    su_adder_for_ambi_irrel #(.ROW(ROW), .COL(COL), .DATA_BITWIDTH(DATA_BITWIDTH), .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .PSUM_RF_ADDR_BITWIDTH(PSUM_RF_ADDR_BITWIDTH),
    .DEPTH(DEPTH)) u_su_adder_for_ambi_irrel(.clk(w2_clk), .reset(w2_reset), .psum_out(w2_psum_out), .pe_psum_finish(w2_pe_psum_finish), .conv_finish(w2_conv_finish), .irrel_num(irrel_rel_num[0]), .rel_num(irrel_rel_num[1]),
    .psum_rf_addr(w2_psum_rf_addr), .su_add_finish(w2_su_add_finish), .out_data(w2_out_data), .psum_gbf_w_en(w2_psum_gbf_w_en), .psum_gbf_w_addr(w2_psum_gbf_w_addr), .psum_gbf_w_num(w2_psum_gbf_w_num));

    mux4 #(.WIDTH(GBF_DATA_BITWIDTH)) out_data_mx(.in0(w0_out_data), .in1(w1_out_data), .in2(w2_out_data), .in3(), .sel(mode[0]), .out(out_data));
    mux4 #(.WIDTH(1)) psum_gbf_w_en_mx(.in0(w0_psum_gbf_w_en), .in1(w1_psum_gbf_w_en), .in2(w2_psum_gbf_w_en), .in3(), .sel(mode[0]), .out(psum_gbf_w_en));
    mux4 #(.WIDTH(GBF_ADDR_BITWIDTH)) psum_gbf_w_addr_mx(.in0(w0_psum_gbf_w_addr), .in1(w1_psum_gbf_w_addr), .in2(w2_psum_gbf_w_addr), .in3(), .sel(mode[0]), .out(psum_gbf_w_addr));
    mux4 #(.WIDTH(1)) psum_gbf_w_num_mx(.in0(w0_psum_gbf_w_num), .in1(w1_psum_gbf_w_num), .in2(w2_psum_gbf_w_num), .in3(), .sel(mode[0]), .out(psum_gbf_w_num));

    localparam [1:0]
        IDLE        =  2'b00,   // do not send data from gbf to sram (when psum_gbf_w_num changes, move to S1 state)
        S1          =  2'b01,   // send data from gbf to sram (when it finished and initialize the gbf value to 0, move to IDLE state)
        FINISH      =  2'b11;
    localparam [4:0] psum_gbf_depth = 5'b11111; //currently using depth=32 psum gbf(2KB)

    reg [1:0] cur_state, nxt_state;
    reg finish;

    always @(negedge clk or posedge reset) begin
        if(reset) begin
            cur_state <= IDLE;
        end
        else
            cur_state <= nxt_state;
    end
    
    //For detecting the posedge and negedge of psum_gbf_w_num
    reg r_psum_gbf_w_num;
    wire w_xor_psum_gbf_w_num = r_psum_gbf_w_num ^ psum_gbf_w_num;
    
    reg [1:0] w_xor_psum_gbf_w_num_delay;

    always@(posedge clk, posedge reset) begin
        if(reset) begin
            w_xor_psum_gbf_w_num_delay <= 2'b11;
        end
        else begin
            w_xor_psum_gbf_w_num_delay <= {w_xor_psum_gbf_w_num_delay[0], w_xor_psum_gbf_w_num};
        end
    end
    
    always @(negedge clk, posedge reset) begin
        if(reset) begin
            r_psum_gbf_w_num <= 1'b0;
        end
        else
            if(~w_xor_psum_gbf_w_num)
                r_psum_gbf_w_num <= ~r_psum_gbf_w_num;
    end
/*
    always @(negedge w_xor_psum_gbf_w_num, posedge reset) begin
        if(reset)
            change_to_S1 <= 1'b0;
         else begin
            change_to_S1 <= 1'b1;
        end
    end
*/
    //State Transition
    always @(posedge clk) begin
        case(cur_state)
            IDLE:
                if(~w_xor_psum_gbf_w_num_delay[1]) begin
                    //$display($time,"su_adder nxt_state is setting to S1 from IDLE");
                    nxt_state <= S1;
                end
                else begin
                    //$display($time,"su_adder state is kept as IDLE");
                    nxt_state <= IDLE;
            end
            S1:
                if(conv_finish) begin
                    //$display($time,"su_adder nxt_state is setting to FINISH from S1");
                    nxt_state <= FINISH;
                end
                else if(finish) begin
                    //$display($time,"su_adder nxt_state is setting to IDLE from S1");
                    nxt_state <= IDLE;
                end
                else begin
                    //$display($time,"su_adder state is kept as S1");
                    nxt_state <= S1;
                end
            FINISH:
                nxt_state <= FINISH;
            default:
                ;
        endcase
    end

    reg delay, flag;
    always @(negedge clk) begin
        //if(reset) begin
        //    psum_gbf_r_en <= 1'b0; psum_gbf_r_addr <= 5'b0;
        //    psum_gbf_w_en_for_init <= 1'b0; psum_gbf_w_addr_for_init <= 5'b0;
        //end
        //else begin
            case(nxt_state)
                IDLE:
                begin
                    psum_gbf_r_en <= 1'b0; psum_gbf_r_addr <= 5'b0;
                    psum_gbf_w_en_for_init <= 1'b0; psum_gbf_w_addr_for_init <= 5'b0;
                    finish <= 1'b0; delay <= 1'b0; flag <= 1'b1;
                end
                S1:
                begin
                    if(psum_gbf_r_addr < psum_gbf_depth) begin
                        psum_gbf_r_en <= 1'b1;
                        if(delay) begin
                            psum_gbf_r_addr <= psum_gbf_r_addr+1; delay <= 1'b0;
                        end
                        else begin
                            if(!psum_gbf_r_addr && flag)
                                flag <= 1'b0;
                            else
                                delay <= 1'b1;
                        end
                    end
                    else begin
                        psum_gbf_r_en <= 1'b0;
                        if(psum_gbf_w_addr_for_init < psum_gbf_depth)begin
                            psum_gbf_w_addr_for_init <= psum_gbf_w_addr_for_init+1;
                            psum_gbf_w_en_for_init <= 1'b1;
                        end
                        else begin
                            psum_gbf_w_en_for_init <= 1'b0; finish <= 1'b1;
                        end
                    end
                end
                default:
                    ;

            endcase
        //end
    end

endmodule