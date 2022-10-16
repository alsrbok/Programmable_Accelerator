//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: PE_new_array
// Description:
//		PE_array with PE_new
//
// History: 2022.08.18 / updated at 2022.08.31 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module PE_new_array #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4,
            parameter GBF_DATA_BITWIDTH     = 256)  //Data Bidwidth from actv,wgt gbf
          ( input clk,
            input reset, input [ROW*COL-1:0] MAC_en, //enalbe signal for MAC from control logic
            input actv_sel, input [ROW*COL-1:0] actv_en, input [ACTV_ADDR_BITWIDTH-1:0] actv_r_addr1, actv_r_addr2, input [ACTV_ADDR_BITWIDTH-1:0] actv_w_addr, input [GBF_DATA_BITWIDTH-1:0] actv_data, input [5*ROW*COL-1 : 0] actv_mux32_sel,
            input wgt_sel, input [ROW*COL-1:0] wgt_en, input [WGT_ADDR_BITWIDTH-1:0] wgt_r_addr1, wgt_r_addr2, input [WGT_ADDR_BITWIDTH-1:0] wgt_w_addr, input [GBF_DATA_BITWIDTH-1:0] wgt_data, input [5*ROW*COL-1 : 0] wgt_mux32_sel,
            input psum_en, input [PSUM_ADDR_BITWIDTH-1:0] psum_addr1, psum_addr2, psum_write_addr,addr_from_su_adder,
            output [OUT_BITWIDTH*ROW*COL-1:0] psum_out
    );

    wire [OUT_BITWIDTH*ROW*COL-1:0] wire_psum1, wire_psum2;
    wire [IN_BITWIDTH*ROW*COL-1:0] wire_actv_data;
    wire [IN_BITWIDTH*ROW*COL-1:0] wire_wgt_data;

    
    genvar i,j;

    generate
        for(i=0; i<ROW; i=i+1) begin : Row
            for(j=0; j<COL; j=j+1) begin : Col

                mux32 #(.WIDTH(IN_BITWIDTH)) wgt_mux(.in(wgt_data), .sel(wgt_mux32_sel[5*(COL*i+j+1)-1 : 5*(COL*i+j)]), .out(wire_wgt_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]));
                mux32 #(.WIDTH(IN_BITWIDTH)) actv_mux(.in(actv_data), .sel(actv_mux32_sel[5*(COL*i+j+1)-1 : 5*(COL*i+j)]), .out(wire_actv_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]));

                PE_new #(.IN_BITWIDTH(IN_BITWIDTH), .OUT_BITWIDTH(OUT_BITWIDTH), .ACTV_ADDR_BITWIDTH(ACTV_ADDR_BITWIDTH), .ACTV_DEPTH(ACTV_DEPTH), .WGT_ADDR_BITWIDTH(WGT_ADDR_BITWIDTH), .WGT_DEPTH(WGT_DEPTH), 
                .PSUM_ADDR_BITWIDTH(PSUM_ADDR_BITWIDTH), .PSUM_DEPTH(PSUM_DEPTH)) pe_new(.clk(clk), .reset(reset), .MAC_en(MAC_en[COL*i+j]), .actv_sel(actv_sel), .actv_en(actv_en[COL*i+j]), .wgt_sel(wgt_sel), .wgt_en(wgt_en[COL*i+j]), .psum_en(psum_en),
                .actv_r_addr1(actv_r_addr1), .actv_w_addr1(actv_w_addr),
                .actv_r_addr2(actv_r_addr2), .actv_w_addr2(actv_w_addr), 
                .actv_data1(wire_actv_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]), .actv_data2(wire_actv_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]),
                .wgt_r_addr1(wgt_r_addr1), .wgt_w_addr1(wgt_w_addr),
                .wgt_r_addr2(wgt_r_addr2), .wgt_w_addr2(wgt_w_addr),
                .wgt_data1(wire_wgt_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]), .wgt_data2(wire_wgt_data[IN_BITWIDTH*(COL*i+j+1)-1 : IN_BITWIDTH*(COL*i+j)]),
                .psum_addr1(psum_addr1), .psum_addr2(psum_addr2), .psum_write_addr(psum_write_addr), .addr_from_su_adder(addr_from_su_adder),
                .psum_out1(wire_psum1[OUT_BITWIDTH*(COL*(ROW-i)-j)-1 : OUT_BITWIDTH*(COL*(ROW-i)-j-1)]), .psum_out2(wire_psum2[OUT_BITWIDTH*(COL*(ROW-i)-j)-1 : OUT_BITWIDTH*(COL*(ROW-i)-j-1)])
                );

                mux2 #(.WIDTH(OUT_BITWIDTH)) mux(.zero(wire_psum1[OUT_BITWIDTH*(COL*(ROW-i)-j)-1 : OUT_BITWIDTH*(COL*(ROW-i)-j-1)]), .one(wire_psum2[OUT_BITWIDTH*(COL*(ROW-i)-j)-1 : OUT_BITWIDTH*(COL*(ROW-i)-j-1)]), 
                .sel(psum_en), .out(psum_out[OUT_BITWIDTH*(COL*(ROW-i)-j)-1 : OUT_BITWIDTH*(COL*(ROW-i)-j-1)])
                );
            end
        end
    endgenerate


endmodule
