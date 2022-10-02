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
                output reg [GBF_DATA_BITWIDTH-1:0] out_data,            //output data which is send to psum gbf
                output reg psum_write_en,                               //output for psum_gbf
                output [9:0] psum_BRAM_addr);                           //output for psum_gbf;
    /*META DATA*/
    //reg [3:0] su_util_num[0:1];    //spatial unrolled operand number, [0]: Row, [1]: Col, 4bit is to represent 0~15 (fully utilized = 15)
    reg [9:0] sram_psum_num[0:1];        //number of psum cycle on sram (rel, irrel), dummy [1]

    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for rel_mem_accumulator ");
            $readmemh("sram_psum_num.mem", sram_psum_num);

            $display("check the initialization");
            $display("sram_psum_num: [0]=%d", sram_psum_num[0]);
        end
    end

    /*REGISTER FOR THE COUNTER*/
    //reg [3:0] su_util_cycle[0:1];
    localparam [2:0] max_su_cycle = 3'b111;
    reg [2:0] su_cycle;             //To represent 16*16/32= 8cycle required for send psum_out to gbf
    reg [9:0] sram_psum_cycle;
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

    always @(negedge clk, posedge reset) begin
        if(reset)
            sram_psum_cycle <= 10'b0;
        else begin
            case(nxt_state)
                IDLE:
                begin
                    //su_util_cycle[0] <= 4'b0; su_util_cycle[1] <= 4'b0;
                    su_cycle <= 3'b0; finish <= 1'b0;
                    psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}}; 
                    out_data <= {GBF_DATA_BITWIDTH{1'b0}}; psum_write_en <= 1'b0;
                end
                S1:
                begin
                    if(su_cycle < max_su_cycle) begin
                        psum_write_en <= 1'b1;
                        if(sram_psum_cycle < sram_psum_num[0]-1)
                            sram_psum_cycle <= sram_psum_cycle + 1;
                        else
                            sram_psum_cycle <= 10'b0;
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
                        su_cycle <= su_cycle + 1;
                    end
                    else begin
                        su_cycle <= 3'b0;
                        if(sram_psum_cycle < sram_psum_num[0]-1)
                            sram_psum_cycle <= sram_psum_cycle + 1;
                        else
                            sram_psum_cycle <= 10'b0;
                        out_data <= psum_out[DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*7-1 : DATA_BITWIDTH*ROW*COL-GBF_DATA_BITWIDTH*8];
                        if(psum_rf_addr < {PSUM_RF_ADDR_BITWIDTH{1'b1}}) begin
                            psum_rf_addr <= psum_rf_addr + 1;
                        end
                        else begin
                            psum_rf_addr <= {PSUM_RF_ADDR_BITWIDTH{1'b0}};
                            finish <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    assign psum_BRAM_addr = sram_psum_cycle;

endmodule