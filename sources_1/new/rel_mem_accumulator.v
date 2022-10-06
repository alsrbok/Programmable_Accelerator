//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: rel_mem_accumulator
// Description:
//		It supports to accumulate partial sum from pe_array. (in order to fit global buffer/sram bandwidth = 512bits)
//      It works when every operand for spatial unrolling is relevant to output(psum)
//      (operands which are irrelevant for output = C(input channel), FX(filter x size), FY(filter y size))
//  
// History: 2022.09.23 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module rel_mem_accumulator #(parameter ROW                   = 16,
                parameter COL                   = 16,
                parameter DATA_BITWIDTH         = 16,
                parameter GBF_DATA_BITWIDTH     = 512,
                parameter PSUM_RF_ADDR_BITWIDTH    = 2,
                parameter DEPTH                 = 32)
              ( input clk, reset, 
                input [DATA_BITWIDTH*ROW*COL-1:0] psum_out,
                input pe_psum_finish, conv_finish,
                output reg [PSUM_RF_ADDR_BITWIDTH-1:0] psum_rf_addr,    //psum address whose data will be used in this module
                output reg su_add_finish,
                output reg [GBF_DATA_BITWIDTH-1:0] out_data,            //output data for psum_gbf
                output reg psum_gbf_w_en,                               //write enable for psum_gbf
                output [4:0] psum_gbf_w_addr,                           //write address for psum_gbf
                output reg psum_gbf_w_num);                             //currently, write data to psum_gbf buf 1(0) / 2(1)
    /*META DATA*/
    reg [7:0] psum_gbf_num[0:1];        //[0]: irrel num on psum_gbf, [1]: rel num on psum_gbf

    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for su_adder_for_ambi_irrel ");
            $readmemh("psum_gbf_num.mem", psum_gbf_num);

            $display("check the initialization");
            $display("psum_gbf_num: [0] [1] =%d %d", psum_gbf_num[0], psum_gbf_num[1]);
        end
    end

    /*REGISTER FOR THE COUNTER*/
    //reg [3:0] su_util_cycle[0:1];
    localparam [2:0] max_su_cycle = 3'b111;
    reg [2:0] su_cycle;             //To represent 16*16/32= 8cycle required for send psum_out to gbf
    reg [7:0] psum_gbf_irrel_cycle;     //irrel cycle on psum_gbf correspond to psum_gbf_num[0]
    reg [4:0] psum_gbf_rel_cycle;       //rel cycle on psum_gbf correspond to psum_gbf_num[1]
    reg finish;                     //When sending psum_out data to gbf is finished, turn on it.


    localparam [1:0]
        IDLE        =  2'b00,
        S1          =  2'b01,
        FINISH      =  2'b11;

    reg [1:0] cur_state, nxt_state;

    always @(negedge clk or posedge reset) begin
        if(reset) begin
            cur_state <= IDLE;
            //nxt_state <= IDLE;
        end
        else
            cur_state <= nxt_state;
    end

    //State Transition
    always @(posedge clk) begin
        case(cur_state)
            IDLE:
                if(pe_psum_finish) begin
                    $display($time,"rel_mem_accumulator nxt_state is setting to S1 from IDLE");
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
                    $display($time,"rel_mem_accumulator nxt_state is setting to IDLE from S1");
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

    reg delay[0:1];
    reg stop, flag, last;

    always @(negedge clk, posedge reset) begin
        if(reset) begin
            psum_gbf_irrel_cycle <= 8'b0; psum_gbf_rel_cycle <= 5'b0; psum_gbf_w_num <= 1'b0;
        end
        else begin
            case(nxt_state)
                IDLE:
                begin
                    //su_util_cycle[0] <= 4'b0; su_util_cycle[1] <= 4'b0;
                    su_cycle <= 3'b0; finish <= 1'b0;
                    psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}}; psum_gbf_rel_cycle <= 5'b0; flag <= 1'b1;
                    out_data <= {GBF_DATA_BITWIDTH{1'b0}}; psum_gbf_w_en <= 1'b0; delay[0] <= 1'b0; delay[1] <= 1'b0; last <= 1'b1;
                end
                S1:
                begin
                    if(su_cycle < max_su_cycle) begin
                        if(psum_gbf_rel_cycle < psum_gbf_num[1]-1) begin
                            if(delay[0]) begin
                                $display($time,"rel_cycle is updated from %d", psum_gbf_rel_cycle);
                                stop <= 1'b0; delay[0] <= 1'b0;
                                psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1;
                            end
                            else begin
                                if(flag) begin
                                    $display($time,"rel_cycle is not updated by flag=1");
                                    stop <= 1'b0; delay[0] <= 1'b0; flag <= 1'b0;
                                end
                                else begin
                                    $display($time,"rel_cycle update is delayed");
                                    delay[0] <= 1'b1;
                                end
                            end
                        end
                        else begin
                            if(delay[0]) begin
                                $display($time,"finish setting");
                                finish <= 1'b1;
                                if(psum_gbf_irrel_cycle < psum_gbf_num[0])
                                    psum_gbf_irrel_cycle <= psum_gbf_irrel_cycle + 1;
                                else begin
                                    psum_gbf_irrel_cycle <= 8'b1; psum_gbf_w_num <= ~psum_gbf_w_num;
                                end
                                delay[0] <= 1'b0;
                            end
                            else begin
                                if(last) begin
                                    $display($time,"rel_cycle is not updated by last=1");
                                    delay[0] <= 1'b0; last <= 1'b0;
                                end
                                else begin
                                    //$display($time,"rel_cycle update is delayed");
                                    $display($time,"rel_cycle is updated from %d", psum_gbf_rel_cycle);
                                    psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1;  delay[0] <= 1'b1;
                                end
                            end
                        end
                        case(su_cycle)
                            3'b000:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH];
                            3'b001:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*1-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*2];
                            3'b010:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*2-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*3];
                            3'b011:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*3-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*4];
                            3'b100:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*4-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*5];
                            3'b101:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*5-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*6];
                            3'b110:
                                out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*6-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*7];
                            default:
                                out_data <= {GBF_DATA_BITWIDTH{1'bx}};
                        endcase
                        stop <= 1'b0;
                        psum_gbf_w_en <= 1'b1;
                        if(delay[1]) begin
                            //$display("time: %d, su_cycle is updated from %d",$time,su_cycle);
                            su_cycle <= su_cycle + 1; delay[1] <= 1'b0;
                        end
                        else begin
                            //$display("time: %d, su_cycle update is delayed",$time);
                            delay[1] <= 1'b1;
                        end
                        
                    end
                    else begin
                        if(delay[1]) begin
                            //$display("time: %d, su_cycle is set to 0",$time);
                            su_cycle <= 3'b0; delay[1] <= 1'b0; stop <= 1'b0;
                        end
                        else begin
                            //$display("time: %d, su_cycle 0 setting is delayed",$time);
                            delay[1] <= 1'b1; stop <= 1'b1;
                        end
                        if(psum_gbf_rel_cycle < psum_gbf_num[1]-1) begin
                            if(delay[0]) begin
                                $display($time,"rel_cycle is updated from %d", psum_gbf_rel_cycle);
                                psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1; delay[0] <= 1'b0;
                            end
                            else begin
                                if(flag) begin
                                    $display($time,"rel_cycle is not updated by flag=1");
                                    delay[0] <= 1'b0; flag <= 1'b0;
                                end
                                else begin
                                    $display($time,"rel_cycle update is delayed");
                                    delay[0] <= 1'b1;
                                end
                            end
                        end
                        else begin
                            if(delay[0]) begin
                                $display($time,"finish setting");
                                finish <= 1'b1;
                                if(psum_gbf_irrel_cycle < psum_gbf_num[0])
                                    psum_gbf_irrel_cycle <= psum_gbf_irrel_cycle + 1;
                                else begin
                                    psum_gbf_irrel_cycle <= 8'b1; psum_gbf_w_num <= ~psum_gbf_w_num;
                                end
                                delay[0] <= 1'b0;
                            end
                            else begin
                                if(last) begin
                                    $display($time,"rel_cycle is not updated by last=1");
                                    delay[0] <= 1'b0; last <= 1'b0;
                                end
                                else begin
                                    //$display($time,"rel_cycle update is delayed");
                                    $display($time,"rel_cycle is updated from %d", psum_gbf_rel_cycle);
                                    psum_gbf_rel_cycle <= psum_gbf_rel_cycle + 1;  delay[0] <= 1'b1;
                                end
                            end
                        end
                        out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*7-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*8];
                        if(!stop)
                            if(psum_rf_addr < {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin
                                //$display("time: %d, psum_rf_addr is updated",$time);
                                psum_rf_addr <= psum_rf_addr + 1;
                            end
                            else begin
                                //$display("time: %d, psum_rf_addr is set to 0",$time);
                                psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}};
                            end
                    end
                end
            endcase
        end
    end

    assign psum_gbf_w_addr = psum_gbf_rel_cycle;

endmodule