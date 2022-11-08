//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_for_ambi_irrel
// Description:
//		It supports to accumulate partial sum from pe_array. (in order to fit global buffer/sram bandwidth = 512bits)
//      spatial unrolling : {irrel 16(D2), rel K(D1), irrel 16/K(D1)} = have irrelevant operand in both side
//      (+ {rel 16(D2), rel 16(D1)} in order to reduce the hardware cost of su_adder_v1)
//      (operands which are irrelevant for output = C(input channel), FX(filter x size), FY(filter y size))
//  
// History: 2022.10.01 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps
(* DONT_TOUCH = "true" *) 
module su_adder_for_ambi_irrel #(parameter ROW                   = 16,
                parameter COL                   = 16,
                parameter DATA_BITWIDTH         = 16,
                parameter GBF_DATA_BITWIDTH     = 512,
                parameter PSUM_RF_ADDR_BITWIDTH    = 2,
                parameter DEPTH                 = 32)
              ( input clk, reset, 
                input [DATA_BITWIDTH*ROW*COL-1:0] psum_out,
                input pe_psum_finish, conv_finish,
                input [4:0] irrel_num,                                  //irrelevant operand number on D1 of pe array :1~16
                input [4:0] rel_num,                                    //relevant operand number on D1 of pe array :16~1
                output reg [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr,    //psum address whose data will be used in this module (output for gbf_pe_array)
                output reg su_add_finish,                               //output for gbf_pe_array
                output [GBF_DATA_BITWIDTH-1:0] out_data,                //output data for psum_gbf
                output reg psum_gbf_w_en_out,                               //write enable for psum_gbf
                output [4:0] psum_gbf_w_addr,                           //write address for psum_gbf
                output reg psum_gbf_w_num);                             //currently, write data to psum_gbf buf 1(0) / 2(1)

    /*META DATA*/
    reg [7:0] psum_gbf_num[0:1];        //[0]: irrel num on psum_gbf - 1, [1]: rel*irrel num on psum_gbf - 1

    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for su_adder_for_ambi_irrel ");
            $readmemh("psum_gbf_num.mem", psum_gbf_num);

            $display("check the initialization");
            $display("psum_gbf_num: [0] [1] =%d %d", psum_gbf_num[0], psum_gbf_num[1]);
        end
    end

    /*REGISTER FOR THE COUNTER*/
    reg [7:0] psum_gbf_irrel_cycle;     //irrel cycle on psum_gbf correspond to psum_gbf_num[0]
    reg [4:0] psum_gbf_rel_cycle;       //rel cycle on psum_gbf correspond to psum_gbf_num[1]
    reg finish;                     //When accumulate psum_out data to accum_psum reg is finished, turn on it to get new one.

    /*REGISTER FOR ACCUMULATED PSUM*/
    reg [GBF_DATA_BITWIDTH-1:0] accum_psum; //512bit reg for accumulating the output data
    reg [4:0] accum_psum_cycle;             //current location to get data from psum_out
    reg accum_psum_flag;                    //flag set to 1 when reg accum_psum cannot store more output data.

    genvar a2, b2, irrel3_2, c2;
    wire [DATA_BITWIDTH-1:0] A2_out[0:ROW*COL/16-1];
    wire [DATA_BITWIDTH-1:0] B2_out[0:ROW*COL/32-1];
    wire [DATA_BITWIDTH-1:0] irrel3_2_out[0:5-1];
    wire [DATA_BITWIDTH-1:0] C2_out[0:ROW*COL/64-1];

    generate
        for(a2=0; a2<ROW*COL/16; a2=a2+1) begin  //total 16 num of A_adder
            adder16 #(.DATA_BITWIDTH(DATA_BITWIDTH)) A2_adder(.in0(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(0)-1) +: DATA_BITWIDTH]), .in1(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(1)-1) +: DATA_BITWIDTH]), .in2(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(2)-1) +: DATA_BITWIDTH]), .in3(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(3)-1) +: DATA_BITWIDTH]), .in4(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(4)-1) +: DATA_BITWIDTH]), .in5(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(5)-1) +: DATA_BITWIDTH]), .in6(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(6)-1) +: DATA_BITWIDTH]),
            .in7(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(7)-1) +: DATA_BITWIDTH]), .in8(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(8)-1) +: DATA_BITWIDTH]), .in9(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(9)-1) +: DATA_BITWIDTH]), .in10(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(10)-1) +: DATA_BITWIDTH]), .in11(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(11)-1) +: DATA_BITWIDTH]), .in12(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(12)-1) +: DATA_BITWIDTH]), .in13(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(13)-1) +: DATA_BITWIDTH]), .in14(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(14)-1) +: DATA_BITWIDTH]),
            .in15(psum_out[DATA_BITWIDTH*(COL*(ROW-a2)-(15)-1) +: DATA_BITWIDTH]), .out(A2_out[a2]));
        end
        
        for(b2=0; b2<ROW*COL/32; b2=b2+1) begin  //total 8 num of A_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) B2_adder(.left(A2_out[2*b2]), .right(A2_out[2*b2+1]), .out(B2_out[b2]));
        end

        for(irrel3_2=0; irrel3_2<5; irrel3_2=irrel3_2+1) begin  //total 5 num of A_adder
            adder3 #(.DATA_BITWIDTH(DATA_BITWIDTH)) irrel3_2_adder(.in0(A2_out[3*irrel3_2]), .in1(A2_out[3*irrel3_2+1]), .in2(A2_out[3*irrel3_2+2]), .out(irrel3_2_out[irrel3_2]));
        end

        for(c2=0; c2<ROW*COL/64; c2=c2+1) begin  //total 4 num of A_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) C2_adder(.left(B2_out[2*c2]), .right(B2_out[2*c2+1]), .out(C2_out[c2]));
        end
    endgenerate

    localparam [1:0]
        IDLE        =  2'b00,
        S1          =  2'b01,
        FINISH      =  2'b11;

    reg [1:0] cur_state, nxt_state;

    always @(negedge clk) begin
        if(reset) begin
            cur_state <= IDLE;
        end
        else
            cur_state <= nxt_state;
    end

    //State Transition
    always @(posedge clk) begin
        case(cur_state)
            IDLE:
                if(pe_psum_finish) begin
                    $display($time,"su_adder_for_ambi_irrel nxt_state is setting to S1 from IDLE");
                    nxt_state <= S1;
                    su_add_finish <= 1'b0;
                end
                else begin
                    //$display($time,"su_adder_for_ambi_irrel state is kept as IDLE");
                    nxt_state <= IDLE;
                    su_add_finish <= 1'b1;
            end
            S1:
                if(conv_finish) begin
                    //$display($time,"su_adder_for_ambi_irrel nxt_state is setting to FINISH from S1");
                    nxt_state <= FINISH;
                    su_add_finish <= 1'bx;
                end
                else if(finish) begin
                    $display($time,"su_adder_for_ambi_irrel nxt_state is setting to IDLE from S1");
                    nxt_state <= IDLE;
                    su_add_finish <= 1'b1;
                end
                else begin
                    //$display($time,"su_adder_for_ambi_irrel state is kept as S1");
                    nxt_state <= S1;
                    su_add_finish <= 1'b0;
                end
            FINISH:
            begin
                nxt_state <= FINISH;
            end
            default:
                ;
        endcase
    end

    integer idx;

    reg delay[0:1];
    reg stop, flag;

    always @(negedge clk) begin
        if(reset) begin
            psum_gbf_irrel_cycle <= 8'b0; psum_gbf_rel_cycle <= 5'b0;
            // when accum_psum become full(accum_psum_flag == 1'b1), enable the psum_gbf_w_en_out to send 512bits data to psum_gbf
            accum_psum <= {GBF_DATA_BITWIDTH{1'b0}}; accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0;
            psum_gbf_w_num <= 1'b0; flag <= 1'b1; stop <= 1'b0; psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}}; 
            //for(idx=0; idx<2; idx=idx+1) begin
            //    delay[idx] <= 1'b0;
            //end
        end
        else begin
            case(nxt_state)
                IDLE:
                begin
                    finish <= 1'b0; psum_gbf_w_en_out <= 1'b0;
                    if(psum_rf_addr != 0)
                        psum_rf_addr <= psum_rf_addr + 1;   //To properly set the rf_addr for the case : (irrel,rel) = (4,3)
                    //psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}}; 
                    for(idx=0; idx<2; idx=idx+1) begin
                        delay[idx] <= 1'b0;
                    end
                end
                S1:
                begin
                    //if(su_cycle < max_su_cycle) begin
                        //accum_psum become full
                        if(accum_psum_flag == 1'b1) begin  
                            if(psum_gbf_rel_cycle < psum_gbf_num[1]) begin
                                if(delay[0]) begin
                                    stop <= 1'b0; delay[0] <= 1'b0;
                                    accum_psum <= {GBF_DATA_BITWIDTH{1'b0}}; accum_psum_cycle <= 5'b0;
                                    psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1;
                                    $display($time,"rel_cycle is updated");
                                end
                                else begin
                                    $display($time,"rel_cycle update is delayed");
                                    delay[0] <= 1'b1;
                                end
                            end
                            else begin
                                if(delay[0]) begin
                                    psum_gbf_rel_cycle <= 5'b0; stop <= 1'b0;
                                    accum_psum <= {GBF_DATA_BITWIDTH{1'b0}}; accum_psum_cycle <= 5'b0;
                                    //$display($time,"psum_gbf_irrel_cycle: %d",psum_gbf_irrel_cycle);
                                    if(psum_gbf_irrel_cycle < psum_gbf_num[0])
                                        psum_gbf_irrel_cycle <= psum_gbf_irrel_cycle + 1;
                                    else begin
                                        psum_gbf_irrel_cycle <= 8'b1; psum_gbf_w_num <= ~psum_gbf_w_num;
                                    end
                                    delay[0] <= 1'b0;
                                end
                                else begin
                                    delay[0] <= 1'b1;
                                end
                            end
                        end

                        case(irrel_num)
                            5'd1:
                            begin
                                case(rel_num)
                                    5'd16:
                                    begin
                                        if(accum_psum_cycle == 0) begin
                                            accum_psum_cycle <= accum_psum_cycle + 16; stop <= 1'b1; flag <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+16) +: DATA_BITWIDTH*16] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14],A2_out[15]};
                                        end
                                        else if(accum_psum_cycle == 16) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; delay[1] <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+16) +: DATA_BITWIDTH*16] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14],A2_out[15]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle == 0) accum_psum_cycle <= accum_psum_cycle + 16; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 16) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+16) +: DATA_BITWIDTH*16] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14],A2_out[15]};
                                    end
                                    5'd15:
                                    begin
                                        if(accum_psum_cycle == 0) begin
                                            accum_psum_cycle <= accum_psum_cycle + 15; stop <= 1'b1; flag <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+16) +: DATA_BITWIDTH*16] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14]};
                                        end
                                        else if(accum_psum_cycle == 15) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; delay[1] <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+16) +: DATA_BITWIDTH*16] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle == 0) accum_psum_cycle <= accum_psum_cycle + 15; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 15) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+15) +: DATA_BITWIDTH*15] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13],A2_out[14]};
                                    end
                                    5'd14:
                                    begin
                                        if(accum_psum_cycle == 0) begin
                                            accum_psum_cycle <= accum_psum_cycle + 14; stop <= 1'b1; flag <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13]};
                                        end
                                        else if(accum_psum_cycle == 14) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; delay[1] <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle == 0) accum_psum_cycle <= accum_psum_cycle + 14; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 14) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12],A2_out[13]};
                                    end
                                    5'd13:
                                    begin
                                        if(accum_psum_cycle == 0) begin
                                            accum_psum_cycle <= accum_psum_cycle + 13; stop <= 1'b1; flag <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12]};
                                        end
                                        else if(accum_psum_cycle == 13) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; delay[1] <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        //if(accum_psum_cycle == 0) accum_psum_cycle <= accum_psum_cycle + 13; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 13) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+13) +: DATA_BITWIDTH*13] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11],A2_out[12]};
                                    end
                                    5'd12:
                                    begin
                                        if(accum_psum_cycle == 0) begin
                                            accum_psum_cycle <= accum_psum_cycle + 12; stop <= 1'b1; flag <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11]};
                                        end
                                        else if(accum_psum_cycle == 12) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; delay[1] <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+14) +: DATA_BITWIDTH*14] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        //if(accum_psum_cycle == 0) accum_psum_cycle <= accum_psum_cycle + 12; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 12) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+12) +: DATA_BITWIDTH*12] <= {A2_out[0],A2_out[1],A2_out[2],A2_out[3],A2_out[4],A2_out[5],A2_out[6],A2_out[7],A2_out[8],A2_out[9],A2_out[10],A2_out[11]};
                                    end
                                    default:
                                        ;
                                endcase
                            end
                            5'd2:
                            begin
                                case(rel_num)
                                    5'd8:
                                    begin
                                        if(accum_psum_cycle < 16) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 8;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+8) +: DATA_BITWIDTH*8] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6],B2_out[7]};
                                        end
                                        else if(accum_psum_cycle == 16) begin
                                            accum_psum_cycle <= accum_psum_cycle + 8; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+8) +: DATA_BITWIDTH*8] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6],B2_out[7]};
                                        end
                                        else if(accum_psum_cycle == 24) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+8) +: DATA_BITWIDTH*8] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6],B2_out[7]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle < 24) accum_psum_cycle <= accum_psum_cycle + 8; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 24) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+8) +: DATA_BITWIDTH*8] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6],B2_out[7]};
                                    end
                                    5'd7:
                                    begin
                                        if(accum_psum_cycle < 14) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 7;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+7) +: DATA_BITWIDTH*7] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6]};
                                        end
                                        else if(accum_psum_cycle == 14) begin
                                            accum_psum_cycle <= accum_psum_cycle + 7; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+7) +: DATA_BITWIDTH*7] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6]};
                                        end
                                        else if(accum_psum_cycle == 21) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0;
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+7) +: DATA_BITWIDTH*7] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle < 21) accum_psum_cycle <= accum_psum_cycle + 7; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 21) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+7) +: DATA_BITWIDTH*7] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5],B2_out[6]};
                                    end
                                    5'd6:
                                    begin
                                        if(accum_psum_cycle < 18) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 6;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+6) +: DATA_BITWIDTH*6] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5]};
                                        end
                                        else if(accum_psum_cycle == 18) begin
                                            accum_psum_cycle <= accum_psum_cycle + 6; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+6) +: DATA_BITWIDTH*6] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5]};
                                        end
                                        else if(accum_psum_cycle == 24) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; 
                                                if(psum_rf_addr == {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin finish <= 1'b1; end
                                                else begin psum_rf_addr <= psum_rf_addr + 1; end
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+6) +: DATA_BITWIDTH*6] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle < 24) accum_psum_cycle <= accum_psum_cycle + 6; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 24) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+6) +: DATA_BITWIDTH*6] <= {B2_out[0],B2_out[1],B2_out[2],B2_out[3],B2_out[4],B2_out[5]};
                                    end
                                    default:
                                        ;
                                endcase
                            end
                            5'd3:
                            begin
                                case(rel_num)
                                    5'd5:
                                    begin
                                        if(accum_psum_cycle < 20) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 5;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+5) +: DATA_BITWIDTH*5] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3],irrel3_2_out[4]};
                                        end
                                        else if(accum_psum_cycle == 20) begin
                                            accum_psum_cycle <= accum_psum_cycle + 5; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+5) +: DATA_BITWIDTH*5] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3],irrel3_2_out[4]};
                                        end
                                        else if(accum_psum_cycle == 25) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; finish <= 1'b1;
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+5) +: DATA_BITWIDTH*5] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3],irrel3_2_out[4]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle < 25) accum_psum_cycle <= accum_psum_cycle + 5; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 25) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+5) +: DATA_BITWIDTH*5] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3],irrel3_2_out[4]};
                                    end
                                    5'd4:
                                    begin
                                        if(accum_psum_cycle < 24) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 4;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3]};
                                        end
                                        else if(accum_psum_cycle == 24) begin
                                            accum_psum_cycle <= accum_psum_cycle + 4; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3]};
                                        end
                                        else if(accum_psum_cycle == 28) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; finish <= 1'b1;
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //if(accum_psum_cycle < 28) accum_psum_cycle <= accum_psum_cycle + 4; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 28) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {irrel3_2_out[0],irrel3_2_out[1],irrel3_2_out[2],irrel3_2_out[3]};
                                    end
                                    default: ;
                                endcase
                            end
                            5'd4:
                            begin
                                case(rel_num)
                                    5'd4:
                                    begin
                                        if(accum_psum_cycle < 24) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 4;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {C2_out[0],C2_out[1],C2_out[2],C2_out[3]};
                                        end
                                        else if(accum_psum_cycle == 24) begin
                                            accum_psum_cycle <= accum_psum_cycle + 4; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {C2_out[0],C2_out[1],C2_out[2],C2_out[3]};
                                        end
                                        else if(accum_psum_cycle == 28) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; finish <= 1'b1;
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+4) +: DATA_BITWIDTH*4] <= {C2_out[0],C2_out[1],C2_out[2],C2_out[3]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                    end
                                    5'd3:
                                    begin
                                        if(accum_psum_cycle < 24) begin
                                            flag <= 1'b1;
                                            accum_psum_cycle <= accum_psum_cycle + 3;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+3) +: DATA_BITWIDTH*3] <= {C2_out[0],C2_out[1],C2_out[2]};
                                        end
                                        else if(accum_psum_cycle == 24) begin
                                            accum_psum_cycle <= accum_psum_cycle + 3; stop <= 1'b1;
                                            accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+3) +: DATA_BITWIDTH*3] <= {C2_out[0],C2_out[1],C2_out[2]};
                                        end
                                        else if(accum_psum_cycle == 27) begin
                                            if(delay[1]) begin
                                                accum_psum_cycle <= 5'b0; accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; finish <= 1'b1;
                                            end
                                            else begin
                                                accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1; 
                                                if(flag) begin
                                                    $display($time,"accum_psum_flag is not updated by flag=1");
                                                    accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+3) +: DATA_BITWIDTH*3] <= {C2_out[0],C2_out[1],C2_out[2]};
                                                    delay[1] <= 1'b0; flag <= 1'b0;
                                                end
                                                else begin
                                                    $display($time,"accum_psum_flag  update is delayed");
                                                    delay[1] <= 1'b1;
                                                end
                                            end
                                        end
                                        else begin accum_psum_flag <= 1'b0; psum_gbf_w_en_out <= 1'b0; end
                                        //For one cycle write. (it cannot accumulate the psum on gbf)
                                        //if(accum_psum_cycle < 27) accum_psum_cycle <= accum_psum_cycle + 3; else accum_psum_cycle <= 5'b0;
                                        //if(accum_psum_cycle == 27) begin accum_psum_flag <= 1'b1; psum_gbf_w_en_out <= 1'b1;end
                                        //else begin accum_psum_flag <= 1'b0; psum_gbf_w_en <= 1'b0; end
                                        //accum_psum[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(accum_psum_cycle+3) +: DATA_BITWIDTH*3] <= {C2_out[0],C2_out[1],C2_out[2]};
                                    end
                                    default: ;
                                endcase
                            end
                            default:
                                ;
                        endcase
                        if(!stop)
                            if(psum_rf_addr < {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin
                                psum_rf_addr <= psum_rf_addr + 1;
                            end
                            else begin
                                psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}};
                                finish <= 1'b1;
                            end

                    //end
                end
                default:
                    ;

            endcase
        end
    end
    assign out_data = accum_psum;
    assign psum_gbf_w_addr = psum_gbf_rel_cycle;

endmodule