//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: su_adder_v1
// Description:
//		It supports to accumulate partial sum from pe_array. (in order to fit global buffer/sram bandwidth = 512bits)
//      spatial unrolling : {rel 16(D2), rel K(D1), irrel 16/K(D1)} (K!=1)
//      (operands which are irrelevant for output = C(input channel), FX(filter x size), FY(filter y size))
//  
// History: 2022.09.27 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+
`timescale 1ns / 1ps

module su_adder_v1 #(parameter ROW                   = 16,
                parameter COL                   = 16,
                parameter DATA_BITWIDTH         = 16,
                parameter GBF_DATA_BITWIDTH     = 512,
                parameter PSUM_RF_ADDR_BITWIDTH    = 2,
                parameter DEPTH                 = 32)
              ( input clk, reset, 
                input [DATA_BITWIDTH*ROW*COL-1:0] psum_out,
                input pe_psum_finish, conv_finish,
                input [4:0] irrel_num,                                   //irrelevant operand number on D1 of pe array :2~16
                output reg [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr,    //psum address whose data will be used in this module (output for gbf_pe_array)
                output reg su_add_finish,                               //output for gbf_pe_array
                output reg [GBF_DATA_BITWIDTH-1:0] out_data,                //output data for psum_gbf
                output reg psum_gbf_w_en,                               //write enable for psum_gbf
                output [4:0] psum_gbf_w_addr,                           //write address for psum_gbf
                output reg psum_gbf_w_num);                             //currently, write data to psum_gbf buf 1(0) / 2(1)

    /*META DATA*/
    //reg [ROW*COL-1:0] A_adder_mode[0:3]; //We should use BRAM
    reg [1:0] A_adder_mode_num[0:1];     //number of used cycle of A_adder_mode, dummy [1] for making it as a memory
    reg [7:0] psum_gbf_num[0:1];        //[0]: irrel num on psum_gbf - 1, [1]: rel*irrel num on psum_gbf - 1

    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for su_adder_v1 ");
            $readmemh("A_adder_mode_num.mem", A_adder_mode_num);
            $readmemh("psum_gbf_num.mem", psum_gbf_num);

            $display("check the initialization");
            $display("psum_gbf_num: [0] [1] =%d %d", psum_gbf_num[0], psum_gbf_num[1]);
        end
    end

    /*REGISTER FOR THE COUNTER*/
    reg [1:0] A_adder_mode_cycle;   //it can be iterate between value of 0 to 3. : address for A_adder_mode_BRAM
    reg [7:0] psum_gbf_irrel_cycle;     //irrel cycle on psum_gbf correspond to psum_gbf_num[0]
    reg [4:0] psum_gbf_rel_cycle;       //rel cycle on psum_gbf correspond to psum_gbf_num[1]
    reg A_addr_en;                 //read enable signal for A_adder_mode_BRAM
    reg [2:0] max_su_cycle;         //Bitwidth should be changed based on maximum cycle number
    reg [2:0] su_cycle;             
    reg finish;                     //When sending psum_out data to gbf is finished, turn on it.

    wire [ROW*COL-1:0] w_A_adder_mode;

    simple_dp_ram #(.DATA_BITWIDTH(256), .ADDR_BITWIDTH(2), .DEPTH(4), .MEM_INIT_FILE("A_adder_mode.mem")
    ) A_adder_mode_BRAM(.clk(clk), .ena(), .enb(A_addr_en), .wea(), .addra(), .addrb(A_adder_mode_cycle), .dia(), .dob(w_A_adder_mode));

    genvar a,b,irrel3,c,irrel5,irrel7;

    wire [DATA_BITWIDTH-1:0] A_out[0:ROW*COL/2-1];
    wire [DATA_BITWIDTH-1:0] B_out[0:ROW*COL/4-1];
    wire [DATA_BITWIDTH-1:0] irrel3_out[0:ROW*COL/8-1];
    wire [DATA_BITWIDTH-1:0] C_out[0:ROW*COL/8-1];
    wire [DATA_BITWIDTH-1:0] irrel5_out[0:ROW*COL/16-1];
    wire [DATA_BITWIDTH-1:0] irrel7_out[0:ROW*COL/16-1];

    generate
        for(a=0; a<ROW*COL/2; a=a+1) begin  //total 128 num of A_adder
            basic_adder #(.DATA_BITWIDTH(DATA_BITWIDTH)) A_adder(.left(psum_out[DATA_BITWIDTH*(COL*(ROW-a/8)-(a%8)*2-1) +: DATA_BITWIDTH]), 
            .right(psum_out[DATA_BITWIDTH*(COL*(ROW-a/8)-(a%8)*2-1-1) +: DATA_BITWIDTH]), .mode(w_A_adder_mode[ROW*COL-2*(a+1) +: 2]), .out(A_out[a]));
        end

        for(b=0; b<ROW*COL/4; b=b+1) begin  //total 64 num of B_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) B_adder(.left(A_out[2*b]), .right(A_out[2*b+1]), .out(B_out[b]));
        end

        for(irrel3=0; irrel3<ROW*COL/8; irrel3=irrel3+1) begin //total 32 num of irrel3_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) irrel3_adder(.left(A_out[8*(irrel3/2)+2*(irrel3%2)+1]), .right(A_out[8*(irrel3/2)+2*(irrel3%2)+2]), .out(irrel3_out[irrel3]));
        end

        for(c=0; c<ROW*COL/8; c=c+1) begin  //total 32 num of C_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) C_adder(.left(B_out[2*c]), .right(B_out[2*c+1]), .out(C_out[c]));
        end

        for(irrel5=0; irrel5<ROW*COL/16; irrel5=irrel5+1) begin //total 16 num of irrel5_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) irrel5_adder(.left(B_out[4*irrel5+1]), .right(B_out[4*irrel5+2]), .out(irrel5_out[irrel5]));
        end

        for(irrel7=0; irrel7<ROW*COL/16; irrel7=irrel7+1) begin //total 16 num of irrel7_adder
            adder2 #(.DATA_BITWIDTH(DATA_BITWIDTH)) irrel7_adder(.left(B_out[4*irrel7+1]), .right(C_out[2*irrel7+1]), .out(irrel7_out[irrel7]));
        end
    endgenerate

    localparam [1:0]
        IDLE        =  2'b00,
        S1          =  2'b01,
        FINISH      =  2'b11;

    reg [1:0] cur_state, nxt_state;

    always @(negedge clk or posedge reset) begin
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
                    //$display("%0t ns rel mem accumulator's nxt stage is setting to S1 from IDLE", $time);
                    nxt_state <= S1;
                    su_add_finish <= 1'b0;
                end
                else begin
                    nxt_state <= IDLE;
                    su_add_finish <= 1'b1;
            end
            S1:
                if(conv_finish) begin
                    nxt_state <= FINISH;
                    su_add_finish <= 1'bx;
                end
                else if(finish) begin
                    nxt_state <= IDLE;
                    su_add_finish <= 1'b1;
                end
                else begin
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

    reg delay[0:2];
    reg stop, flag;
    always @(negedge clk, posedge reset) begin
        if(reset) begin
            psum_gbf_irrel_cycle <= 8'b0; psum_gbf_rel_cycle <= 5'b0;
            psum_gbf_w_en <= 1'b0; psum_gbf_w_num <= 1'b0; flag <= 1'b1;
        end
        else begin
            case(nxt_state)
                IDLE:
                begin
                    su_cycle <= 3'b0; finish <= 1'b0;
                    psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}}; out_data <= {GBF_DATA_BITWIDTH{1'b0}};
                    A_adder_mode_cycle <= 2'b00; A_addr_en <= 1'b1; psum_gbf_w_en <= 1'b0;
                    for(idx=0; idx<3; idx=idx+1) begin
                        delay[idx] <= 1'b0;
                    end
                    //sram_psum_cycle <= sram_psum_cycle;
                    case(irrel_num)
                        5'd2: max_su_cycle <= 3'd4;
                        5'd3: max_su_cycle <= 3'd3;
                        5'd4: max_su_cycle <= 3'd2;
                        5'd5: max_su_cycle <= 3'd2;
                        5'd6: max_su_cycle <= 3'd2;
                        5'd7: max_su_cycle <= 3'd2;
                        5'd8: max_su_cycle <= 3'd1;
                        default: max_su_cycle <=5'd0;
                    endcase
                end
                S1:
                begin
                    //if(su_cycle < max_su_cycle) begin
                        //output for A_adder_BRAM is generate at negedge clk (data from BRAM will be send at posedge clk to A_adder)
                        if(A_adder_mode_num[0] == 2'b01)
                            A_adder_mode_cycle <= 2'b00;
                        else begin
                            if(A_adder_mode_cycle < A_adder_mode_num[0]) begin
                                $display($time,"ns, A_adder_mode_cycle : %d",A_adder_mode_cycle);
                                $display($time,"ns, w_A_adder_mode : %h",w_A_adder_mode);
                                if(delay[0]) begin
                                    A_adder_mode_cycle <= A_adder_mode_cycle + 1; delay[0] <= 1'b0;
                                end
                                else begin
                                    delay[0] <= 1'b1;
                                end
                            end
                            else begin
                                $display($time,"ns, A_adder_mode_cycle : %d",A_adder_mode_cycle);
                                $display($time,"ns, w_A_adder_mode : %h",w_A_adder_mode);
                                A_adder_mode_cycle <= 2'b00;
                            end
                        end
                        //output for psum_gbf
                        if(psum_gbf_rel_cycle < psum_gbf_num[1]) begin
                            if(delay[1]) begin
                                $display($time,"rel_cycle is updated");
                                psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1; delay[1] <= 1'b0;
                            end
                            else begin
                                if(stop) begin
                                    $display($time,"rel_cycle is not updated by stop=1");
                                    delay[1] <= 1'b0;
                                end
                                else
                                    if(flag) begin
                                        $display($time,"rel_cycle is not updated by flag=1");
                                        delay[1] <= 1'b0; flag <= 1'b0;
                                    end
                                    else begin
                                        $display($time,"rel_cycle update is delayed");
                                        delay[1] <= 1'b1;
                                    end
                            end
                        end
                        else begin
                             if(delay[1]) begin
                                psum_gbf_rel_cycle <= 5'b0; //flag <= 1'b1;
                                $display($time,"psum_gbf_irrel_cycle: %d", psum_gbf_irrel_cycle);
                                if(psum_gbf_irrel_cycle < psum_gbf_num[0])
                                    psum_gbf_irrel_cycle <= psum_gbf_irrel_cycle + 1;
                                else begin
                                    $display($time,"change the psum_gbf_w_num");
                                    psum_gbf_irrel_cycle <= 8'b1; psum_gbf_w_num <= ~psum_gbf_w_num;
                                end
                                delay[1] <= 1'b0;
                            end
                            else begin
                                if(stop)
                                    delay[1] <= 1'b0;
                                else
                                    delay[1] <= 1'b1;
                            end
                        end

                        case(irrel_num)
                            5'd2:
                            begin
                                for(idx=0; idx<32; idx=idx+1)
                                    out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= A_out[su_cycle*32+idx];
                            end
                            5'd3:
                                case(su_cycle)
                                    5'd0: 
                                        for(idx=0; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= B_out[2*idx];
                                    5'd1:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= B_out[4*idx+3];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end
                                    5'd2:
                                        for(idx=0; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= irrel3_out[idx];
                                    default:    ;
                                endcase
                            5'd4:
                                for(idx=0; idx<32; idx=idx+1)
                                    out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= B_out[su_cycle*32+idx];
                            5'd5:
                                case(su_cycle)
                                    5'd0:
                                        for(idx=0; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= C_out[idx];
                                    5'd1:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= irrel5_out[idx];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end   
                                endcase
                            5'd6:
                                case(su_cycle)
                                    5'd0:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= C_out[2*idx];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end   
                                    5'd1:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= irrel5_out[idx];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end   
                                endcase
                            5'd7:
                                case(su_cycle)
                                    5'd0:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= C_out[2*idx];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end   
                                    5'd1:
                                    begin
                                        for(idx=0; idx<16; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= irrel7_out[idx];
                                        for(idx=16; idx<32; idx=idx+1)
                                            out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= {DATA_BITWIDTH{1'b0}};
                                    end   
                                endcase
                            5'd8:
                                for(idx=0; idx<32; idx=idx+1)
                                    out_data[GBF_DATA_BITWIDTH-DATA_BITWIDTH*(idx+1) +: DATA_BITWIDTH] <= C_out[idx];
                                
                            default:
                                out_data <= {GBF_DATA_BITWIDTH{1'bx}};
                        endcase
                        if(su_cycle < max_su_cycle) begin
                            stop <= 1'b0;
                            psum_gbf_w_en <= 1'b1;
                            if(delay[2]) begin
                                su_cycle <= su_cycle + 1; delay[2] <= 1'b0;
                            end
                            else begin
                                delay[2] <= 1'b1;
                            end
                        end
                        else begin
                            stop <= 1'b1;
                            psum_gbf_w_en <= 1'b0;
                            su_cycle <= 3'b0;
                            if(psum_rf_addr < {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin
                                psum_rf_addr <= psum_rf_addr + 1;
                            end
                            else begin
                                psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}};
                                finish <= 1'b1;
                            end
                        end
                    //end
                end
                default:
                    ;

            endcase
        end
    end

    assign psum_gbf_w_addr = psum_gbf_rel_cycle;

endmodule