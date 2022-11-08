//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: accelerator_port
// Description:
//		
//      
//      
//  
// History: 2022.10.14 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module accelerator_port #(parameter ROW          = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH     = 256,
            parameter GBF_ADDR_BITWIDTH     = 5,    //Addr Bitwidth for actv/wgt gbf
            parameter GBF_DEPTH             = 32,   //Depth for actv/wgt gbf
            parameter PSUM_GBF_DATA_BITWIDTH= 512,
            parameter PSUM_GBF_ADDR_BITWIDTH= 5,    //Addr Bitwidth for psum gbf
            parameter PSUM_GBF_DEPTH        = 32) //Depth for psum gbf
        (   input clk, reset,
            //input for actv/wgt gbf buffer
            //output of gbf_controller
            output actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data,
            //output of psum_gbf_wrapper
            output [PSUM_GBF_DATA_BITWIDTH/4-1:0] reduced_r_data1b,
            output [PSUM_GBF_DATA_BITWIDTH/4-1:0] reduced_r_data2b,
            output reg [31:0] initial_data1b,
            output reg [31:0] initial_data2b,
            output r_en1b_out, r_en2b_out
            //output r0_psum_gbf_w_num, r1_psum_gbf_w_num, r2_psum_gbf_w_num
            );

    reg actv_en1a, actv_en2a, actv_we1a, actv_we2a, wgt_en1a, wgt_en2a, wgt_we1a, wgt_we2a;
    reg [GBF_ADDR_BITWIDTH-1:0] actv_addr1a, actv_addr2a, wgt_addr1a, wgt_addr2a;
    reg [GBF_DATA_BITWIDTH-1:0] actv_w_data1a, actv_w_data2a, wgt_w_data1a, wgt_w_data2a;
    reg finish, gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready;

    always @(posedge reset) begin
        if(reset) begin
            actv_en1a<=1'b0; actv_en2a<=1'b0; actv_we1a<=1'b0; actv_we2a<=1'b0; wgt_en1a<=1'b0; wgt_en2a<=1'b0; wgt_we1a<=1'b0; wgt_we2a<=1'b0;
            actv_addr1a<={GBF_ADDR_BITWIDTH{1'b0}}; actv_addr2a<={GBF_ADDR_BITWIDTH{1'b0}}; wgt_addr1a<={GBF_ADDR_BITWIDTH{1'b0}}; wgt_addr2a<={GBF_ADDR_BITWIDTH{1'b0}};
            actv_w_data1a<={GBF_DATA_BITWIDTH{1'b0}}; actv_w_data2a<={GBF_DATA_BITWIDTH{1'b0}}; wgt_w_data1a<={GBF_DATA_BITWIDTH{1'b0}}; wgt_w_data2a<={GBF_DATA_BITWIDTH{1'b0}};
            finish<=1'b0; gbf_actv_data_avail<=1'b1; gbf_wgt_data_avail<=1'b1; gbf_actv_buf1_ready<=1'b1; gbf_actv_buf2_ready<=1'b1; gbf_wgt_buf1_ready<=1'b1; gbf_wgt_buf2_ready<=1'b1;
        end
    end

    wire [PSUM_GBF_DATA_BITWIDTH-1:0] r_data1b, r_data2b;

    accelerator_w_o_sram #(.ROW(ROW), .COL(COL), .IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH),
    .GBF_DATA_BITWIDTH(GBF_DATA_BITWIDTH), .GBF_ADDR_BITWIDTH(GBF_ADDR_BITWIDTH), .GBF_DEPTH(GBF_DEPTH), .PSUM_GBF_DATA_BITWIDTH(PSUM_GBF_DATA_BITWIDTH), .PSUM_GBF_ADDR_BITWIDTH(PSUM_GBF_ADDR_BITWIDTH), .PSUM_GBF_DEPTH(PSUM_GBF_DEPTH)) u_accelerator_w_o_sram(
    .clk(clk), .reset(reset), .actv_en1a(actv_en1a), .actv_en2a(actv_en2a), .actv_we1a(actv_we1a), .actv_we2a(actv_we2a), .wgt_en1a(wgt_en1a), .wgt_en2a(wgt_en2a), .wgt_we1a(wgt_we1a), .wgt_we2a(wgt_we2a), 
    .actv_addr1a(actv_addr1a), .actv_addr2a(actv_addr2a), .wgt_addr1a(wgt_addr1a), .wgt_addr2a(wgt_addr2a), .actv_w_data1a(actv_w_data1a), .actv_w_data2a(actv_w_data2a), .wgt_w_data1a(wgt_w_data1a), .wgt_w_data2a(wgt_w_data2a), .finish(finish), .gbf_actv_data_avail(gbf_actv_data_avail), .gbf_wgt_data_avail(gbf_wgt_data_avail),
    .gbf_actv_buf1_ready(gbf_actv_buf1_ready), .gbf_actv_buf2_ready(gbf_actv_buf2_ready), .gbf_wgt_buf1_ready(gbf_wgt_buf1_ready), .gbf_wgt_buf2_ready(gbf_wgt_buf2_ready), .actv_gbf1_need_data(actv_gbf1_need_data), .actv_gbf2_need_data(actv_gbf2_need_data),
    .wgt_gbf1_need_data(wgt_gbf1_need_data), .wgt_gbf2_need_data(wgt_gbf2_need_data), .r_data1b(r_data1b), .r_data2b(r_data2b), .r_en1b_out(r_en1b_out), .r_en2b_out(r_en2b_out)
    /*.r0_psum_gbf_w_num(r0_psum_gbf_w_num), .r1_psum_gbf_w_num(r1_psum_gbf_w_num), .r2_psum_gbf_w_num(r2_psum_gbf_w_num)*/);

    assign reduced_r_data1b = r_data1b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH*3/4];
    assign reduced_r_data2b = r_data2b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH*3/4];

    reg [2:0] idx1, idx2;

    always@(negedge clk) begin
        if(reset) begin
            idx1 <= 3'b0; initial_data1b <= 32'b0;
        end
        else begin
            if(idx1 < 3'b011) begin
                if(r_en1b_out) begin
                    case(idx1)
                        3'b000:
                        begin
                            initial_data1b[31:16] <= r_data1b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH-16];
                            idx1 <= idx1 + 1;
                        end
                        3'b001:
                            idx1 <= idx1 + 1;
                        3'b010:
                        begin
                            initial_data1b[15:0] <= r_data1b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH-16];
                            idx1 <= idx1 + 1;
                        end
                    endcase
                end
            end
        end
    end

    always@(negedge clk) begin
        if(reset) begin
            idx2 <= 3'b0; initial_data2b <= 32'b0;
        end
        else begin
            if(idx2 < 3'b101) begin
                if(r_en2b_out) begin
                    case(idx2)
                        3'b000:
                        begin
                            initial_data2b[31:16] <= r_data2b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH-16];
                            idx2 <= idx2 + 1;
                        end
                        3'b001:
                            idx2 <= idx2 + 1;
                        3'b010:
                            idx2 <= idx2 + 1;
                        3'b011:
                            idx2 <= idx2 + 1;
                        3'b100:
                        begin
                            initial_data2b[15:0] <= r_data2b[PSUM_GBF_DATA_BITWIDTH-1:PSUM_GBF_DATA_BITWIDTH-16];
                            idx2 <= idx2 + 1;
                        end
                    endcase
                end
            end
        end
    end
endmodule