//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: MAC_new
// Description:
//		MAC_new support seperation of write_addr and sum_in location.
//		
//
// History: 2022.08.15 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module MAC_new #( parameter IN_BITWIDTH = 8,
			  parameter OUT_BITWIDTH = 16,
			  parameter PSUM_ADDR_BITWIDTH = 2)
			( input [IN_BITWIDTH-1 : 0] a_in,
			  input [IN_BITWIDTH-1 : 0] w_in,
			  input [OUT_BITWIDTH-1 : 0] sum_in,
			  input [PSUM_ADDR_BITWIDTH-1 : 0] psum_write_addr, // write address of psum for current a_in, w_in (get from control logic)
			  input en, clk,						//en : control logic give signal to calculate
			  output reg [PSUM_ADDR_BITWIDTH-1 : 0] write_addr, //write address of psum for current a_in, w_in (send to rf_psum)
			  output reg [OUT_BITWIDTH-1 : 0] out,
			  output reg out_en						//out_en : MAC make signal of output enable (It makes rf_psum to write output value to its memory)
			);
	
	//reg [OUT_BITWIDTH-1:0] mult_out;
	
	always@(negedge clk) begin
		if(en) begin
			//mult_out = a_in * w_in;
			//out = mult_out + sum_in;
			out = a_in * w_in + sum_in;
			out_en = 1'b1;
			write_addr = psum_write_addr;
			$display("%0t ns : a_in / w_in / sum_in / write_addr / out / out_en = %d / %d / %d / %d / %d / %b ", $time, a_in, w_in, sum_in, psum_write_addr, out, out_en);
		end
		else begin out = 0; out_en = 1'b0; end
	end
	
endmodule