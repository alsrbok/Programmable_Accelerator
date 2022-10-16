//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: rf_iw_sync_dpdb
// Description:
//		Synchronized Dual-Port Double-Buffer RF for Activation and Weight
//		
//
// History: 2022.08.09 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module rf_iw_sync_dpdb #( parameter DATA_BITWIDTH = 8,
			 parameter ADDR_BITWIDTH = 2,
             parameter DEPTH = 4 ) //default register size is 8*4=32bits
		   ( input clk,
			 input reset,
			 input write_sel,	// if write_sel == 1 : update mem1 from global buffer data && read data from mem2(which send to MAC) -> It will support by MUX signal
			 input write_en,
			 input [ADDR_BITWIDTH-1 : 0] r_addr1, w_addr1,
			 input [DATA_BITWIDTH-1 : 0] w_data1,
             input [ADDR_BITWIDTH-1 : 0] r_addr2, w_addr2,
			 input [DATA_BITWIDTH-1 : 0] w_data2,
			 output reg [DATA_BITWIDTH-1 : 0] r_data1,
             output reg [DATA_BITWIDTH-1 : 0] r_data2
    );
	
	reg [DATA_BITWIDTH-1 : 0] mem1 [0 : DEPTH - 1]; // default - 512-bit memory.
    reg [DATA_BITWIDTH-1 : 0] mem2 [0 : DEPTH - 1]; // default - 512-bit memory.

    integer i;

	always@(posedge clk or posedge reset)
		begin : BUFFER1
			if(reset) begin
                r_data1 <= 0;
			end
			else begin
				if(write_sel) begin
					if(write_en) begin
						$display("%0t ns : write buffer1[%d] = %d ", $time, w_addr1, w_data1);
						mem1[w_addr1] <= w_data1;
					end
				end
                r_data1 <= mem1[r_addr1];
			end
		end
    
	always@(posedge clk or posedge reset)
		begin : BUFFER2
			if(reset) begin
                r_data2 <= 0;
			end
			else begin
				if(!write_sel) begin
					if(write_en) begin
						$display("%0t ns : write buffer2[%d] = %d ", $time, w_addr2, w_data2);
						mem2[w_addr2] <= w_data2;
					end
				end
                r_data2 <= mem2[r_addr2];
			end
		end

endmodule

