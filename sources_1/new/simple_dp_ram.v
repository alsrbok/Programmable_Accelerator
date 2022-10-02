//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: simple_dp_ram
// Description:
//		Simple Dual-port RAM(with ena, enb pin) wrapper (N_DELAY = 1. Bandwidth = 512bits/cycle)
//		FPGA = 1: Use the generated RAM 
//		Otherwise: Use a RAM modeling
//
// History: 2022.09.17 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

`define FPGA 0
module simple_dp_ram #(parameter DATA_BITWIDTH    = 256,
                parameter ADDR_BITWIDTH         = 3,
                parameter DEPTH                 = 8,
                parameter MEM_INIT_FILE = "" )
              ( input clk, ena, enb, wea,
                input [ADDR_BITWIDTH-1 : 0] addra, addrb,
                input [DATA_BITWIDTH-1 : 0] dia, 
                output [DATA_BITWIDTH-1 : 0] dob
    );

    
    `ifdef FPGA
    //------------------------------------------------------------------------+
	// Implement ip generate block ram
	//------------------------------------------------------------------------+
    
        generate
		if((DATA_BITWIDTH==256) && (DEPTH==8) && (MEM_INIT_FILE=="rf_actv_en.mem")) begin: gen_actv_en_BRAM
			actv_en_BRAM u_actv_en_BRAM( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
		end
        else if((DATA_BITWIDTH==256) && (DEPTH==8) && (MEM_INIT_FILE=="rf_wgt_en.mem")) begin: gen_wgt_en_BRAM
            wgt_en_BRAM u_wgt_en_BRAM( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==1280) && (DEPTH==8) && (MEM_INIT_FILE=="rf_actv_mux32.mem")) begin: gen_actv_mux32_BRAM
            actv_mux32_BRAM u_actv_mux32_BRAM( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==1280) && (DEPTH==8) && (MEM_INIT_FILE=="rf_wgt_mux32.mem")) begin : gen_wgt_mux32_BRAM
            wgt_mux32_BRAM u_wgt_mux32_BRAM( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==512) && (DEPTH==32) && (MEM_INIT_FILE=="gbf_actv_buf1.mem"))begin : gen_gbf_actv_buf1
            gbf_actv_buf1 u_gbf_actv_buf1( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==512) && (DEPTH==32) && (MEM_INIT_FILE=="gbf_actv_buf2.mem"))begin : gen_gbf_actv_buf1
            gbf_actv_buf2 u_gbf_actv_buf2( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==512) && (DEPTH==32) && (MEM_INIT_FILE=="gbf_wgt_buf1.mem"))begin : gen_gbf_wgt_buf1
            gbf_wgt_buf1 u_gbf_wgt_buf1( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==512) && (DEPTH==32) && (MEM_INIT_FILE=="gbf_wgt_buf2.mem"))begin : gen_gbf_wgt_buf1
            gbf_wgt_buf2 u_gbf_wgt_buf2( 
				.clka(~clk), .clkb(~clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
        else if((DATA_BITWIDTH==256) && (DEPTH==4) && (MEM_INIT_FILE=="A_adder_mode.mem"))begin : gen_A_adder_mode
            A_adder_mode_BRAM u_A_adder_mode_BRAM( //it need posedge output
				.clka(clk), .clkb(clk), .ena(ena), .enb(enb), .wea(wea),
				.addra(addra), .addrb(addrb),
				.dina(dia), .doutb(dob)
			);
        end
	    endgenerate
    
    `else 
    
        //------------------------------------------------------------------------+
        // Memory modeling
        //------------------------------------------------------------------------+
        reg [DATA_BITWIDTH-1 : 0] mem[0 : DEPTH-1];

        initial begin
            if (MEM_INIT_FILE != "") begin
                $display("intialize the simple_dp_ram");
                $readmemh(MEM_INIT_FILE, mem);
            end
        end

        //write when ena is 1 (by using only port A)
        always @(negedge clk) begin
            if(ena) begin
                if(wea)
                    mem[addra] <= dia;
            end
        end
        //read when enb is 1 (by using only port B)
        always @(negedge clk) begin
            if(enb) begin
                dob <= mem[addrb];
            end
        end

    `endif

endmodule