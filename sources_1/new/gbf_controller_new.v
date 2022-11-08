//------------------------------------------------------------+
// Project: Spatial Accelerator
// Module: gbf_controller_new
// Description:
//		gbf_controller_new which generate read-address and enable signal for actv/wgt global buffer.
//      It communicates with SRAM controller and pe_array_controleer in order to generate addr and signals in correct order
//      It does not care the action inside the pe_array_w_controller module.
//
// History: 2022.09.14 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module gbf_controller_new #(parameter ROW          = 16,   //PE array row size
                parameter COL                           = 16,
                parameter ACTV_ADDR_BITWIDTH            = 2,   //Decide rf_input memory size
                parameter WGT_ADDR_BITWIDTH             = 2,
                parameter GBF_DATA_BITWIDTH             = 256,  //Data Bitwidth/Bandwith for actv/wgt gbf
                parameter GBF_ADDR_BITWIDTH             = 5,    //Addr Bitwidth for actv/wgt gbf
                parameter GBF_DEPTH                     = 32 )  //Depth for actv/wgt gbf
          ( input clk, reset, finish,
            input gbf_actv_data_avail, gbf_wgt_data_avail, gbf_actv_buf1_ready, gbf_actv_buf2_ready, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready, //input signal from sram controller
            input /*rf_turn_off,*/ actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data, // input signal from pe_array_controller
            output reg [GBF_ADDR_BITWIDTH-1:0] actv_gbf_addrb, wgt_gbf_addrb, // read address for actv/wgt gbf
            output reg actv_gbf_en1b, actv_gbf_en2b, wgt_gbf_en1b, wgt_gbf_en2b, // read enable signal for each gbf(port B)
            output reg actv_mux_gbf2rf, wgt_mux_gbf2rf, // mux selection signal (between r_data1b and rdata2b from actv/wgt gbf)
            output reg [2:0] actv_mux32_addr, wgt_mux32_addr, // address for mux selection which send to BRAM (cycle 3)
            output reg actv_gbf1_need_data, actv_gbf2_need_data, wgt_gbf1_need_data, wgt_gbf2_need_data,  // output signal to sram controller(same function with actv/wgt_rf1/2_need_data)
            output reg actv_rf_end_out, wgt_rf_end_out, //mux sel for en_BRAM output
            //signal to pe_array_w_controller
            output reg [2:0] rf_actv_en_addr/*[ROW*COL-1:0] rf_actv_en*/, output reg [ACTV_ADDR_BITWIDTH-1:0] rf_actv_w_addr,
            output reg [2:0] rf_wgt_en_addr/*[ROW*COL-1:0] rf_wgt_en*/, output reg [WGT_ADDR_BITWIDTH-1:0] rf_wgt_w_addr,
            output reg rf_actv_data_avail, rf_wgt_data_avail, rf_actv_buf1_send_finish, rf_actv_buf2_send_finish, rf_wgt_buf1_send_finish, rf_wgt_buf2_send_finish,
            output reg conv_finish);


    /*META-DATA : [0] is for actv, [1] is for wgt*/
    //cycle 1: address for global buffer
    localparam max_rel_bitwdith = 7;                // It can be modified based on new empirical result.
    localparam max_rel_length = 64 ;
    
    reg [max_rel_bitwdith-1:0] gbf_rel_num[0:1];    //alpha: number of relevant operand on the gbf level.
    reg [max_rel_bitwdith-1:0] gbf_irrel_num[0:1];  //beta : number of irrelevant operand on the gbf level.
    reg [2:0] gbf_per_tm_num[0:1];                  //gamma: repeated number of gbf address in order to send data on different rf's tm address (use only 1,2,4 value)
    
    reg [max_rel_bitwdith-1:0] gbf_actv_rel_addr[0:max_rel_length-1]; //a for actv: cycle of address which only deal with the relevant
    reg [max_rel_bitwdith-1:0] gbf_wgt_rel_addr[0:max_rel_length-1];  //a for wgt

    reg [5:0] gbf_addr_per_rf[0:1];                                   //b: to fill out one rf buffer, it require b number of address on gbf = (rf_su_rel * rf_tm_rel)/32
    // e.g. case 1: b=1) alpha[0]=4, beta[0]=3, gamma[0]=2 => gbf address: {(00) (11) (22) (33)} X 3(beta)  [It should send (xx) when rf require the data]
    // e.g. case 2: b=8) alpha[0]=2, beta[0]=3, gamma[0]=1 => gbf address: {(01234567) (89101112131415)} X 3(beta)

    //cycle 2: address for rf to be stored
    localparam max_tm_cycle_bitwidth = 6; 
    localparam max_tm_cycle_length   = 32;
    reg [max_tm_cycle_bitwidth-1:0] rf_tm_num[0:1];                               //length of tm address cycle
    reg [ACTV_ADDR_BITWIDTH-1:0] rf_actv_tm_addr[0:max_tm_cycle_length-1];     //tm address cycle for actv (maximum length is 32=max(16*16*4/32, 4))
    reg [WGT_ADDR_BITWIDTH-1:0] rf_wgt_tm_addr[0:max_tm_cycle_length-1];       //tm address cycle for actv

    //cycle 3: mux sel
    reg [2:0] rf_mux32_addr_cycle_num[0:1];                        //max value= 16*16/32=8, data is located in the BRAM

    //cycle 4: write enable signal for each operand's rf
    reg [2:0] rf_en_cycle_num[0:1];                         //max value= 16*16/32=8 => use 4bits
    //reg [ROW*COL-1:0] rf_actv_en_cycle[0:7];
    //reg [ROW*COL-1:0] rf_wgt_en_cycle[0:7];

    
    /*REGISTER FOR THE COUNTER*/
    //cycle 1
    reg [max_rel_bitwdith-1:0] gbf_rel_cycle[0:1];          //for alpha cycle
    reg [max_rel_bitwdith-1:0] gbf_irrel_cycle[0:1];        //for beta cycle
    reg [2:0] gbf_per_tm_cycle[0:1];                        //for gamma cycle
    reg [5:0] gbf_addr_per_rf_cycle[0:1];                   //for b cycle
    //cycle 2
    reg [max_tm_cycle_bitwidth-1:0] rf_tm_cycle[0:1];       //for address for rf cycle
    //cycle 3
    reg [2:0] rf_mux32_addr_cycle[0:1];                   //for mux32_addr_cycle : It will be substituted by output reg actv_mux32_addr, wgt_mux32_addr

    //cycle 4
    reg [2:0] rf_en_cycle[0:1];                             //for write enable signal for rf cycle
    
    /*REGISTER FOR CHECKPOINT*/
    reg actv_rf_end, wgt_rf_end;                            //1: current rf buffer is full
    reg actv_gbf_num, wgt_gbf_num;                          //0: using gbf buf 1 for sending data to rf, 1: using gbf buf 2
    reg actv_gbf_end, wgt_gbf_end;                          //0: current gbf can be used more, 1: should be changed to the another side of buffer (alpha become to max value)

    //assign actv_rf_end_out = actv_rf_end;
    //assign wgt_rf_end_out = wgt_rf_end;

    /*REGISTER FOR CURRENT USING RF BUF NUM & DETECTING THE USAGE OF SENT DATA*/
    wire actv_rf_num, wgt_rf_num;                            //0: current PE get data at rf buf 1, 1: current PE get data at rf buf 2
    //reg actv_rf_is_used, wgt_rf_is_used;                    //0: sent data is not yet used in rf, 1: sent data is used in rf

    /*REGISTER FOR storing send_finish*/
    //reg rf_actv_rf1_send_finish, rf_actv_rf2_send_finish, rf_wgt_rf1_send_finish, rf_wgt_rf2_send_finish;

    //initialize the meta-data
    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for gbf controller ");
            $readmemh("gbf_controller_gbf_rel_num.mem", gbf_rel_num);
            $readmemh("gbf_controller_gbf_irrel_num.mem", gbf_irrel_num);
            $readmemh("gbf_controller_gbf_per_tm_num.mem", gbf_per_tm_num);
            $readmemh("gbf_controller_gbf_actv_rel_addr.mem", gbf_actv_rel_addr);
            $readmemh("gbf_controller_gbf_wgt_rel_addr.mem", gbf_wgt_rel_addr);
            $readmemh("gbf_controller_gbf_addr_per_rf.mem", gbf_addr_per_rf);
            $readmemh("gbf_controller_rf_tm_num.mem", rf_tm_num);
            $readmemh("gbf_controller_rf_actv_tm_addr.mem", rf_actv_tm_addr);
            $readmemh("gbf_controller_rf_wgt_tm_addr.mem", rf_wgt_tm_addr);
            $readmemh("gbf_controller_rf_mux32_addr_cycle_num.mem", rf_mux32_addr_cycle_num);
            $readmemh("gbf_controller_rf_en_cycle_num.mem", rf_en_cycle_num);


            $display("check the initialization");
            $display("gbf_rel_num: [0]=%d / [1]=%d", gbf_rel_num[0], gbf_rel_num[1]);
            $display("gbf_irrel_num: [0]=%d / [1]=%d", gbf_irrel_num[0], gbf_irrel_num[1]);
            $display("gbf_per_tm_num: [0]=%d / [1]=%d", gbf_per_tm_num[0], gbf_per_tm_num[1]);
            $display("gbf_actv_rel_addr: %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d /", gbf_actv_rel_addr[0], gbf_actv_rel_addr[1], gbf_actv_rel_addr[2], gbf_actv_rel_addr[3], gbf_actv_rel_addr[4], gbf_actv_rel_addr[5], gbf_actv_rel_addr[6], gbf_actv_rel_addr[7], gbf_actv_rel_addr[8], gbf_actv_rel_addr[9], gbf_actv_rel_addr[10], gbf_actv_rel_addr[11], gbf_actv_rel_addr[12], gbf_actv_rel_addr[13], gbf_actv_rel_addr[14], gbf_actv_rel_addr[15] , gbf_actv_rel_addr[16], gbf_actv_rel_addr[17], gbf_actv_rel_addr[18], gbf_actv_rel_addr[19], gbf_actv_rel_addr[20], gbf_actv_rel_addr[21], gbf_actv_rel_addr[22], gbf_actv_rel_addr[23], gbf_actv_rel_addr[24], gbf_actv_rel_addr[25], gbf_actv_rel_addr[26], gbf_actv_rel_addr[27], gbf_actv_rel_addr[28], gbf_actv_rel_addr[29], gbf_actv_rel_addr[30], gbf_actv_rel_addr[31]);
            $display("gbf_wgt_rel_addr: %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d /", gbf_wgt_rel_addr[0], gbf_wgt_rel_addr[1], gbf_wgt_rel_addr[2], gbf_wgt_rel_addr[3], gbf_wgt_rel_addr[4], gbf_wgt_rel_addr[5], gbf_wgt_rel_addr[6], gbf_wgt_rel_addr[7], gbf_wgt_rel_addr[8], gbf_wgt_rel_addr[9], gbf_wgt_rel_addr[10], gbf_wgt_rel_addr[11], gbf_wgt_rel_addr[12], gbf_wgt_rel_addr[13], gbf_wgt_rel_addr[14], gbf_wgt_rel_addr[15] , gbf_wgt_rel_addr[16], gbf_wgt_rel_addr[17], gbf_wgt_rel_addr[18], gbf_wgt_rel_addr[19], gbf_wgt_rel_addr[20], gbf_wgt_rel_addr[21], gbf_wgt_rel_addr[22], gbf_wgt_rel_addr[23], gbf_wgt_rel_addr[24], gbf_wgt_rel_addr[25], gbf_wgt_rel_addr[26], gbf_wgt_rel_addr[27], gbf_wgt_rel_addr[28], gbf_wgt_rel_addr[29], gbf_wgt_rel_addr[30], gbf_wgt_rel_addr[31]);
            $display("gbf_addr_per_rf: [0]=%d / [1]=%d", gbf_addr_per_rf[0], gbf_addr_per_rf[1]);
            $display("rf_tm_num: [0]=%d / [1]=%d", rf_tm_num[0], rf_tm_num[1]);
            $display("rf_actv_tm_addr: %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d /", rf_actv_tm_addr[0], rf_actv_tm_addr[1], rf_actv_tm_addr[2], rf_actv_tm_addr[3], rf_actv_tm_addr[4], rf_actv_tm_addr[5], rf_actv_tm_addr[6], rf_actv_tm_addr[7], rf_actv_tm_addr[8], rf_actv_tm_addr[9], rf_actv_tm_addr[10], rf_actv_tm_addr[11], rf_actv_tm_addr[12], rf_actv_tm_addr[13], rf_actv_tm_addr[14], rf_actv_tm_addr[15] , rf_actv_tm_addr[16], rf_actv_tm_addr[17], rf_actv_tm_addr[18], rf_actv_tm_addr[19], rf_actv_tm_addr[20], rf_actv_tm_addr[21], rf_actv_tm_addr[22], rf_actv_tm_addr[23], rf_actv_tm_addr[24], rf_actv_tm_addr[25], rf_actv_tm_addr[26], rf_actv_tm_addr[27], rf_actv_tm_addr[28], rf_actv_tm_addr[29], rf_actv_tm_addr[30], rf_actv_tm_addr[31]);
            $display("rf_wgt_tm_addr: %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d /", rf_wgt_tm_addr[0], rf_wgt_tm_addr[1], rf_wgt_tm_addr[2], rf_wgt_tm_addr[3], rf_wgt_tm_addr[4], rf_wgt_tm_addr[5], rf_wgt_tm_addr[6], rf_wgt_tm_addr[7], rf_wgt_tm_addr[8], rf_wgt_tm_addr[9], rf_wgt_tm_addr[10], rf_wgt_tm_addr[11], rf_wgt_tm_addr[12], rf_wgt_tm_addr[13], rf_wgt_tm_addr[14], rf_wgt_tm_addr[15] , rf_wgt_tm_addr[16], rf_wgt_tm_addr[17], rf_wgt_tm_addr[18], rf_wgt_tm_addr[19], rf_wgt_tm_addr[20], rf_wgt_tm_addr[21], rf_wgt_tm_addr[22], rf_wgt_tm_addr[23], rf_wgt_tm_addr[24], rf_wgt_tm_addr[25], rf_wgt_tm_addr[26], rf_wgt_tm_addr[27], rf_wgt_tm_addr[28], rf_wgt_tm_addr[29], rf_wgt_tm_addr[30], rf_wgt_tm_addr[31]);
            $display("rf_mux32_addr_cycle_num: [0]=%d / [1]=%d", rf_mux32_addr_cycle_num[0], rf_mux32_addr_cycle_num[1]);
            $display("rf_en_cycle_num: [0]=%d / [1]=%d", rf_en_cycle_num[0], rf_en_cycle_num[1]);

        end
    end

    localparam [2:0]
        IDLE        =  3'b000,  // Initially begin to compute new layer (nothing happen to gbf)
        delay_S1    =  3'b001,
        S1          =  3'b010,  // actv/wgt_gbf buffer1 send data to actv/wgt_rf buffer1
        S2          =  3'b011,  // actv/wgt_gbf bufferX send data to actv/wgt_rf buffer2
        WAIT        =  3'b100,
        init_S3     =  3'b101,
        S3          =  3'b110,
        FINISH      =  3'b111;

    reg [2:0] cur_state, nxt_state;

    always @(negedge clk) begin
        if(reset) begin
            cur_state <= IDLE;
            //nxt_state <= IDLE;
        end
        else
            cur_state <= nxt_state;
    end
    /**********************************************************************/
    assign actv_rf_num = !actv_rf1_need_data & actv_rf2_need_data;
    reg old_actv_rf_num;
    always @(negedge clk) begin
        if(reset)
            old_actv_rf_num <= 1'b0;
        else
            old_actv_rf_num <= actv_rf_num;
    end
    /*wire actv_is_swap;
    assign actv_is_swap = actv_rf_num ^ old_actv_rf_num;*/
    
    reg actv_is_swap, actv_is_swap2;
    always @(posedge clk) begin
        if(reset)
            actv_is_swap <= 1'b0;
        else
            actv_is_swap <= actv_rf_num ^ old_actv_rf_num;
            actv_is_swap2 <= actv_is_swap;
    end
    /*
    reg r_actv_rf1_need_data;   //This can detect the initial change of rf1_need_data (negedge & posedge)
    wire w_xor_actv_rf1_need_data = r_actv_rf1_need_data ^ actv_rf1_need_data;

    reg [1:0] w_xor_actv_rf1_need_delay;

    always@(posedge clk) begin
        if(reset) begin
            w_xor_actv_rf1_need_delay <= 2'b11;
        end
        else begin
            w_xor_actv_rf1_need_delay <= {w_xor_actv_rf1_need_delay[0], w_xor_actv_rf1_need_data};
        end
    end
    //new one : LUTAR-1 warning, zero output
    reg prevent_swap[0:1];
    always@(posedge clk, negedge w_xor_actv_rf1_need_data, posedge reset) begin
        if(!w_xor_actv_rf1_need_data) begin
            if(prevent_swap[0]) begin
                $display("actv rf num is swaped!");
                actv_rf_num <= ~actv_rf_num;
                prevent_swap[0] <= 1'b0;
            end
            else begin
                prevent_swap[0] <= 1'b1;
            end
        end
        else begin
            if(reset) begin
                $display("actv rf num is initialized!");
                actv_rf_num <= 1'b0;
                prevent_swap[0] <= 1'b1;
            end
        end
    end*/

    //old one : signal cannot be used as clk in FPGA (clk is not reached)
    /*
    always @(negedge w_xor_actv_rf1_need_data, posedge reset) begin
        if(reset) begin
            $display("actv rf num is initialized!");
            actv_rf_num <= 1'b0;
        end
         else begin
            $display("actv rf num is swaped!");
            actv_rf_num <= ~actv_rf_num;
        end
    end*/
    /*
    always @(negedge clk) begin
        if(reset)
            r_actv_rf1_need_data <= 1'b0;
        else begin
            if(~w_xor_actv_rf1_need_data)
                r_actv_rf1_need_data <= ~r_actv_rf1_need_data;
        end
    end*/
    /*---------------------------------------------------------------------*/
    /*always @(posedge clk) begin
        if(reset)
            actv_rf_is_used <= 1'b0;
        else
            if(!actv_rf2_need_data)
                actv_rf_is_used <= 1'b1;
            else
                actv_rf_is_used <= 1'b0;
    end*/
    /*
    reg r_actv_rf2_need_data;   //This can detect the change of rf2_need_data (do not consider the initial change of rf1_need_data at S2 state)
    wire w_xor_actv_rf2_need_data = r_actv_rf2_need_data ^ actv_rf2_need_data;
    //new one: LUTAR-1 warning
    always@(posedge clk, negedge w_xor_actv_rf2_need_data, posedge reset) begin
        if(!w_xor_actv_rf2_need_data) begin
            actv_rf_is_used <= 1'b1;
        end
        else begin
            if(reset)
                actv_rf_is_used <= 1'b0;
        end
    end*/
    //old one
    /*
    always @(negedge w_xor_actv_rf2_need_data, posedge reset) begin
        if(reset) begin
            actv_rf_is_used <= 1'b0;
        end
        else begin
            actv_rf_is_used <= 1'b1;
        end
    end*/
    /**********************************************************************/
    assign wgt_rf_num = !wgt_rf1_need_data & wgt_rf2_need_data;
    reg old_wgt_rf_num;
    always @(negedge clk) begin
        if(reset)
            old_wgt_rf_num <= 1'b0;
        else
            old_wgt_rf_num <= wgt_rf_num;
    end
    /*wire wgt_is_swap;
    assign wgt_is_swap = wgt_rf_num ^ old_wgt_rf_num;*/
    
    reg wgt_is_swap, wgt_is_swap2;
    always @(posedge clk) begin
        if(reset)
            wgt_is_swap <= 1'b0;
        else begin
            wgt_is_swap <= wgt_rf_num ^ old_wgt_rf_num;
            wgt_is_swap2 <= wgt_is_swap;
        end
    end
    /*
    reg r_wgt_rf1_need_data;
    wire w_xor_wgt_rf1_need_data = r_wgt_rf1_need_data ^ wgt_rf1_need_data;

    reg [1:0] w_xor_wgt_rf1_need_delay;

    always@(posedge clk) begin
        if(reset) begin
            w_xor_wgt_rf1_need_delay <= 2'b11;
        end
        else begin
            w_xor_wgt_rf1_need_delay <= {w_xor_wgt_rf1_need_delay[0], w_xor_wgt_rf1_need_data};
        end
    end
    //new one: LUTAR-1 warning
    always@(posedge clk, negedge w_xor_wgt_rf1_need_data, posedge reset) begin
        if(!w_xor_wgt_rf1_need_data)
            if(prevent_swap[1]) begin
                wgt_rf_num <= ~wgt_rf_num;
                prevent_swap[1] <= 1'b0;
            end
            else begin
                prevent_swap[1] <= 1'b1;
            end
        else begin
            if(reset) begin
                wgt_rf_num <= 1'b0;
                prevent_swap[1] <= 1'b1;
            end
        end
    end
    */
    //old one
    /*
    always @(negedge w_xor_wgt_rf1_need_data, posedge reset) begin
        if(reset) begin
            wgt_rf_num <= 1'b0; 
        end
         else begin
            wgt_rf_num <= ~wgt_rf_num;
            $display($time,"My new wgt function is working now");
            $display($time,"r_wgt_rf1_need_data : %d",r_wgt_rf1_need_data);
        end
    end*/
    /*
    always @(negedge clk) begin
        if(reset)
            r_wgt_rf1_need_data <= 1'b0;
        else begin
            if(~w_xor_wgt_rf1_need_data)
                r_wgt_rf1_need_data <= ~r_wgt_rf1_need_data;
        end
    end*/
    /*---------------------------------------------------------------------*/
    /*
    always @(posedge clk) begin
        if(reset)
            wgt_rf_is_used <= 1'b0;
        else
            if(!wgt_rf2_need_data) begin
                $display($time,"wgt_rf_is_used is set to 1");
                wgt_rf_is_used <= 1'b1;
            end
            else
                wgt_rf_is_used <= 1'b0;
    end*/
    /*
    reg r_wgt_rf2_need_data;
    wire w_xor_wgt_rf2_need_data = r_wgt_rf2_need_data ^ wgt_rf2_need_data;
    //new one: LUTAR-1 warning
    always@(posedge clk, negedge w_xor_wgt_rf2_need_data, posedge reset) begin
        if(!w_xor_wgt_rf2_need_data) begin
            $display($time,"wgt_rf_is_used is set to 1");
            wgt_rf_is_used <= 1'b1;
        end
        else begin
            if(reset)
                wgt_rf_is_used <= 1'b0;
        end
    end*/
    //old one
    /*
    always @(negedge w_xor_wgt_rf2_need_data, posedge reset) begin
        if(reset) begin
            wgt_rf_is_used <= 1'b0;
        end
        else begin
            wgt_rf_is_used <= 1'b1;
            $display($time,"My brand new wgt function is working now");
            $display("%0t ns actv_rf_is_used = %b ", $time, actv_rf_is_used);
            $display("%0t ns wgt_rf_is_used = %b ", $time, wgt_rf_is_used);
        end
    end*/

    reg delayS1_to_S2;
    always @(posedge clk) begin
        case(cur_state)
            IDLE:
                if(gbf_actv_data_avail && gbf_wgt_data_avail) begin
                    $display("%0t ns gbf controller's nxt stage is setting to delay_S1 ", $time);
                    nxt_state <= delay_S1;
                    delayS1_to_S2 <= 1'b0;
                end
                else begin
                    nxt_state <= IDLE;
                end
            delay_S1:
                if(finish)
                    nxt_state <= FINISH;
                else
                    if (delayS1_to_S2) begin
                        $display("%0t ns gbf controller's nxt stage is setting to S2 from delay_S1", $time);
                        nxt_state <= S2;
                    end
                    else begin
                        $display("%0t ns gbf controller's nxt stage is setting to S1 from delay_S1", $time);
                        nxt_state <= S1;
                    end

            S1:
                if(rf_actv_buf1_send_finish && rf_wgt_buf1_send_finish) begin //It can be modified to actv_rf_end, wgt_rf_end: state change 1 cycle
                    $display("%0t ns gbf controller's nxt stage is setting to delay_S1 from S1 ", $time);
                    nxt_state <= delay_S1; delayS1_to_S2 <= 1'b1;
                end
                else begin
                    nxt_state <= S1;
                end
            S2:
                if(~rf_actv_buf2_send_finish && ~rf_wgt_buf2_send_finish) begin
                    $display($time,"keep S2 state");
                    $display("%0t ns actv_gbf_en1b = %b ", $time, actv_gbf_en1b);
                    $display("%0t ns wgt_gbf_en1b = %b ", $time, wgt_gbf_en1b);
                    nxt_state <= S2;
                end
                else if(actv_gbf_end || wgt_gbf_end) begin
                    $display("%0t ns actv_gbf_end / wgt_gbf_end= %d / %d  ", $time, actv_gbf_end, wgt_gbf_end);
                    $display("%0t ns actv_gbf_num / gbf_actv_buf1_ready / gbf_actv_buf2_ready= %d / %d / %d ", $time, actv_gbf_num, gbf_actv_buf1_ready, gbf_actv_buf2_ready);
                    $display("%0t ns wgt_gbf_num / gbf_wgt_buf1_ready / gbf_wgt_buf2_ready= %d / %d / %d ", $time, wgt_gbf_num, gbf_wgt_buf1_ready, gbf_wgt_buf2_ready);
                    if(actv_gbf_end && wgt_gbf_end) begin
                        if(((~actv_gbf_num)&&(~gbf_actv_buf1_ready)) || ((actv_gbf_num)&&(~gbf_actv_buf2_ready)) || ((~wgt_gbf_num)&&(~gbf_wgt_buf1_ready)) || ((wgt_gbf_num)&&(~gbf_wgt_buf2_ready)))begin
                            $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                            nxt_state <= WAIT;
                        end
                        else begin
                            if((~actv_rf_end) && (~wgt_rf_end)) begin
                                $display("%0t ns gbf controller's nxt stage is setting to init_S3 from S2 ", $time);
                                nxt_state <= init_S3;
                            end
                            else begin
                                $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                                nxt_state <= WAIT;
                            end
                        end
                    end
                    else if(actv_gbf_end) begin
                        if(((~actv_gbf_num)&&(~gbf_actv_buf1_ready)) || ((actv_gbf_num)&&(~gbf_actv_buf2_ready))) begin
                            $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                            nxt_state <= WAIT;
                        end
                        else begin
                            if((~actv_rf_end) && (~wgt_rf_end)) begin
                                $display("%0t ns gbf controller's nxt stage is setting to init_S3 from S2 ", $time);
                                nxt_state <= init_S3;
                            end
                            else begin
                                $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                                nxt_state <= WAIT;
                            end
                        end
                    end
                    else if(wgt_gbf_end) begin
                        if(((~wgt_gbf_num)&&(~gbf_wgt_buf1_ready)) || ((wgt_gbf_num)&&(~gbf_wgt_buf2_ready))) begin
                             $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                            nxt_state <= WAIT;
                        end
                        else begin
                            if((~actv_rf_end) && (~wgt_rf_end)) begin
                                $display("%0t ns gbf controller's nxt stage is setting to init_S3 from S2 ", $time);
                                nxt_state <= init_S3;
                            end
                            else begin
                                $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                                nxt_state <= WAIT;
                            end
                        end
                    end
                end
                else
                    if((~actv_rf_end) && (~wgt_rf_end)) begin
                        $display("%0t ns gbf controller's nxt stage is setting to init_S3 from S2 ", $time);
                        $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b = %d / %d ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                        //$display("%0t ns actv_gbf_en1b / actv_rf_is_used / wgt_gbf_en1b / wgt_rf_is_used = %d / %d / %d / %d", $time, actv_gbf_en1b ,actv_rf_is_used ,wgt_gbf_en1b ,wgt_rf_is_used);
                        nxt_state <= init_S3;
                    end
                    else begin
                        $display("%0t ns gbf controller's nxt stage is setting to WAIT from S2 ", $time);
                        nxt_state <= WAIT;
                    end
            init_S3:
                if(finish) begin
                    $display("%0t ns gbf controller's nxt stage is setting to FINISH from init_S3 ", $time);
                    nxt_state <= FINISH;
                end
                else begin
                    $display("%0t ns gbf controller's nxt stage is setting to S3 from init_S3 ", $time);
                    nxt_state <= S3;
                end
            S3:
                if(finish) begin
                    $display("%0t ns gbf controller's nxt stage is setting to FINISH from S3 ", $time);
                    nxt_state <= FINISH;
                end
                else if((((actv_gbf_num)&&(actv_gbf_en2b)) || ((~actv_gbf_num)&&(actv_gbf_en1b))) && (((wgt_gbf_num)&&(wgt_gbf_en2b)) || ((~wgt_gbf_num)&&(wgt_gbf_en1b)))) begin 
                    nxt_state <= S3;
                end
                else begin
                    $display("%0t ns gbf controller's nxt stage is setting to WAIT from S3 ", $time);
                    //$display("%0t ns actv_gbf_num / actv_gbf_en2b / actv_gbf_en1b /actv_rf_is_used /wgt_gbf_num / wgt_gbf_en2b / wgt_gbf_en1b /wgt_rf_is_used= %d / %d / %d / %d / %d / %d / %d / %d ", $time, actv_gbf_num , actv_gbf_en2b , actv_gbf_en1b ,actv_rf_is_used ,wgt_gbf_num , wgt_gbf_en2b , wgt_gbf_en1b ,wgt_rf_is_used);
                    //actv_rf_is_used <= 1'b0; wgt_rf_is_used <= 1'b0;
                    nxt_state <= WAIT;
                end
            WAIT:
            begin
                nxt_state <= WAIT;
                //$display("%0t ns actv_gbf_num / actv_gbf_en2b / actv_gbf_en1b /actv_rf_is_used /wgt_gbf_num / wgt_gbf_en2b / wgt_gbf_en1b /wgt_rf_is_used= %d / %d / %d / %d / %d / %d / %d / %d ", $time, actv_gbf_num , actv_gbf_en2b , actv_gbf_en1b ,actv_rf_is_used ,wgt_gbf_num , wgt_gbf_en2b , wgt_gbf_en1b ,wgt_rf_is_used);
                /*
                if(actv_gbf_end && wgt_gbf_end) begin
                    //actv,wgt_gbf_num is swapped when end is set to 1. Therefore, num=0 means that it is time to use buf 1 
                    if(((~actv_gbf_num)&&(~gbf_actv_buf1_ready)) || ((actv_gbf_num)&&(~gbf_actv_buf2_ready)) || ((~wgt_gbf_num)&&(~gbf_wgt_buf1_ready)) || ((wgt_gbf_num)&&(~gbf_wgt_buf2_ready)))begin
                        $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                        nxt_state <= WAIT;
                    end
                    else
                        if(actv_rf_is_used || wgt_rf_is_used) begin
                            $display("%0t ns gbf controller's nxt stage is setting to init_S3 from WAIT ", $time);
                            nxt_state <= init_S3;
                        end
                        else begin
                            $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                            nxt_state <= WAIT;
                        end
                end 
                else if(actv_gbf_end) begin
                    if(((~actv_gbf_num)&&(~gbf_actv_buf1_ready)) || ((actv_gbf_num)&&(~gbf_actv_buf2_ready))) begin
                        $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                        nxt_state <= WAIT;
                    end
                    else    // only actv gbf num is swapped. wgt gbf num is preserved.
                        if(actv_rf_is_used || wgt_rf_is_used) begin
                            $display("%0t ns gbf controller's nxt stage is setting to init_S3 from WAIT ", $time);
                            nxt_state <= init_S3;
                        end
                        else begin
                            $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                            nxt_state <= WAIT;
                        end
                end
                else if(wgt_gbf_end) begin
                    if(((~wgt_gbf_num)&&(~gbf_wgt_buf1_ready)) || ((wgt_gbf_num)&&(~gbf_wgt_buf2_ready))) begin
                        $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                        nxt_state <= WAIT;
                    end
                    else    // only wgt gbf num is swapped. actv gbf num is preserved.
                        if(actv_rf_is_used || wgt_rf_is_used) begin
                            $display("%0t ns gbf controller's nxt stage is setting to init_S3 from WAIT ", $time);
                            nxt_state <= init_S3;
                        end
                        else begin
                            $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                            nxt_state <= WAIT;
                        end
                end
                else    // actv, wgt gbf num is preserved. (like from S2 state)
                    if(actv_rf_is_used || wgt_rf_is_used) begin
                        $display("%0t ns gbf controller's nxt stage is setting to init_S3 from WAIT ", $time);
                        nxt_state <= init_S3;
                    end
                    else begin
                        $display("%0t ns gbf controller's nxt stage is setting to WAIT from WAIT ", $time);
                        nxt_state <= WAIT;
                    end*/
            end
            FINISH:
                nxt_state <= FINISH;
            default:
                nxt_state <= IDLE;
        endcase
    end

    //negedge output
    always @(negedge clk) begin
        if(reset) begin
            //set the output value
            actv_mux_gbf2rf <= 1'bx; wgt_mux_gbf2rf <= 1'bx;
            actv_gbf1_need_data <= 1'b1; actv_gbf2_need_data <= 1'b1; wgt_gbf1_need_data <= 1'b1; wgt_gbf2_need_data <= 1'b1;
            rf_actv_w_addr <= {ACTV_ADDR_BITWIDTH{1'bx}}; rf_wgt_w_addr <= {WGT_ADDR_BITWIDTH{1'bx}};
            rf_actv_data_avail <= 1'b0; rf_wgt_data_avail <= 1'b0;
            conv_finish <= 1'b0;
            rf_actv_buf1_send_finish <= 1'b0; rf_actv_buf2_send_finish <= 1'b0; rf_wgt_buf1_send_finish <= 1'b0; rf_wgt_buf2_send_finish <= 1'b0;
        end
        else begin
            case(cur_state) //non-blocking assignment
                IDLE:
                begin
                    $display("negedge %0t ns gbf controller's cur state: IDLE ", $time);
                    actv_mux_gbf2rf <= 1'bx; wgt_mux_gbf2rf <= 1'bx;
                    actv_gbf1_need_data <= 1'b1; actv_gbf2_need_data <= 1'b1; wgt_gbf1_need_data <= 1'b1; wgt_gbf2_need_data <= 1'b1;
                    rf_actv_w_addr <= {ACTV_ADDR_BITWIDTH{1'bx}}; rf_wgt_w_addr <= {WGT_ADDR_BITWIDTH{1'bx}};
                    rf_actv_data_avail <= 1'b0; rf_wgt_data_avail <= 1'b0;
                    conv_finish <= 1'b0;
                end
                delay_S1:
                begin
                    $display("negedge %0t ns gbf controller's cur state: delay_S1 ", $time);
                    rf_actv_data_avail <= 1'b1; rf_wgt_data_avail <= 1'b1; 
                end
                S1:
                begin
                    $display("negedge %0t ns gbf controller's cur state: S1 ", $time);
                    rf_actv_data_avail <= 1'b1; rf_wgt_data_avail <= 1'b1; 
                    actv_mux_gbf2rf <= 1'b0; wgt_mux_gbf2rf <= 1'b0;
                    actv_gbf1_need_data <= 1'b0; actv_gbf2_need_data <= 1'b1; wgt_gbf1_need_data <= 1'b0; wgt_gbf2_need_data <= 1'b1;
                    rf_actv_w_addr <= rf_actv_tm_addr[rf_tm_cycle[0]]; rf_wgt_w_addr <= rf_wgt_tm_addr[rf_tm_cycle[1]];
                    if(actv_rf_end) begin rf_actv_buf1_send_finish <= 1'b1; end else begin rf_actv_buf1_send_finish <= 1'b0; end
                    if(wgt_rf_end) begin rf_wgt_buf1_send_finish <= 1'b1; end else begin rf_wgt_buf1_send_finish <= 1'b0; end
                    if(/*~w_xor_actv_rf1_need_delay[0]*/actv_is_swap) begin
                        $display($time, "state S1/ actv_is_swap: %d", actv_is_swap);
                        if(~actv_rf_num) rf_actv_buf1_send_finish <= 1'b0; else rf_actv_buf2_send_finish <= 1'b0;
                        if(actv_gbf_end) actv_mux_gbf2rf <= ~actv_mux_gbf2rf;
                    end
                    if(/*~w_xor_wgt_rf1_need_delay[0]*/wgt_is_swap) begin
                        $display($time, "state S1/ wgt_is_swap: %d", wgt_is_swap);
                        if(~wgt_rf_num) rf_wgt_buf1_send_finish <= 1'b0; else rf_wgt_buf2_send_finish <= 1'b0;
                        if(wgt_gbf_end) wgt_mux_gbf2rf <= ~wgt_mux_gbf2rf;
                    end
                    conv_finish <= 1'b0;
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns rf_actv_w_addr / rf_wgt_w_addr: %h / %d  ", $time, rf_actv_w_addr, rf_wgt_w_addr);
                    $display("%0t ns rf_actv_buf1_send_finish / rf_wgt_buf1_send_finish: %d / %d  ", $time, rf_actv_buf1_send_finish, rf_wgt_buf1_send_finish);
                end
                S2:
                begin
                    $display("negedge %0t ns gbf controller's cur state: S2 ", $time);
                    actv_mux_gbf2rf <= 1'b0; wgt_mux_gbf2rf <= 1'b0;
                    actv_gbf1_need_data <= 1'b0; actv_gbf2_need_data <= 1'b1; wgt_gbf1_need_data <= 1'b0; wgt_gbf2_need_data <= 1'b1;
                    rf_actv_w_addr <= rf_actv_tm_addr[rf_tm_cycle[0]]; rf_wgt_w_addr <= rf_wgt_tm_addr[rf_tm_cycle[1]];
                    if(nxt_state == init_S3) begin  // Eventhough nxt_state is set to init_S3 and make buf2_send_finish to zero, cur_state use S2.
                        rf_actv_buf2_send_finish <= 1'b0; rf_wgt_buf2_send_finish <= 1'b0;
                    end
                    else begin
                        if(actv_rf_end) begin rf_actv_buf2_send_finish <= 1'b1; end else begin rf_actv_buf2_send_finish <= 1'b0; end
                        if(wgt_rf_end) begin rf_wgt_buf2_send_finish <= 1'b1; end else begin rf_wgt_buf2_send_finish <= 1'b0; end
                    end
                    if(/*~w_xor_actv_rf1_need_delay[0]*/actv_is_swap) begin
                        if(~actv_rf_num) rf_actv_buf1_send_finish <= 1'b0; else rf_actv_buf2_send_finish <= 1'b0;
                        if(actv_gbf_end) actv_mux_gbf2rf <= ~actv_mux_gbf2rf;
                    end
                    if(/*~w_xor_wgt_rf1_need_delay[0]*/wgt_is_swap) begin
                        if(~wgt_rf_num) rf_wgt_buf1_send_finish <= 1'b0; else rf_wgt_buf2_send_finish <= 1'b0;
                        if(wgt_gbf_end) wgt_mux_gbf2rf <= ~wgt_mux_gbf2rf;
                    end
                    conv_finish <= 1'b0;
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns rf_actv_w_addr / rf_wgt_w_addr: %h / %d  ", $time, rf_actv_w_addr, rf_wgt_w_addr);
                    $display("%0t ns rf_actv_buf2_send_finish / rf_wgt_buf2_send_finish: %d / %d  ", $time, rf_actv_buf2_send_finish, rf_wgt_buf2_send_finish);
                end
                init_S3:
                begin
                    $display("negedge %0t ns gbf controller's cur state: init_S3 ", $time);
                    if(/*~w_xor_actv_rf1_need_delay[0]*/actv_is_swap) begin
                        if(~actv_rf_num) rf_actv_buf1_send_finish <= 1'b0; else rf_actv_buf2_send_finish <= 1'b0;
                        if(actv_gbf_end) actv_mux_gbf2rf <= ~actv_mux_gbf2rf;
                    end
                    if(/*~w_xor_wgt_rf1_need_delay[0]*/wgt_is_swap) begin
                        if(~wgt_rf_num) rf_wgt_buf1_send_finish <= 1'b0; else rf_wgt_buf2_send_finish <= 1'b0;
                        if(wgt_gbf_end) wgt_mux_gbf2rf <= ~wgt_mux_gbf2rf;
                    end
                    if(actv_gbf_end) begin actv_gbf1_need_data <= ~actv_gbf1_need_data; actv_gbf2_need_data <= ~actv_gbf2_need_data; end else begin actv_gbf1_need_data <= actv_gbf1_need_data; actv_gbf2_need_data <= actv_gbf2_need_data; end
                    if(wgt_gbf_end) begin wgt_gbf1_need_data <= ~wgt_gbf1_need_data; wgt_gbf2_need_data <= ~wgt_gbf2_need_data; end else begin wgt_gbf1_need_data <= wgt_gbf1_need_data; wgt_gbf2_need_data <= wgt_gbf2_need_data; end
                end
                WAIT:
                begin
                    $display("negedge %0t ns gbf controller's cur state: WAIT ", $time);
                    //$display("w_xor_actv_rf1_need_data: %d", w_xor_actv_rf1_need_data);
                    //$display("w_xor_actv_rf1_need_delay [1] [0]: %d %d", w_xor_actv_rf1_need_delay[1], w_xor_actv_rf1_need_delay[0]);
                    if(/*~w_xor_actv_rf1_need_delay[0]*/actv_is_swap) begin
                        if(~actv_rf_num) rf_actv_buf1_send_finish <= 1'b0; else rf_actv_buf2_send_finish <= 1'b0;
                        if(actv_gbf_end) actv_mux_gbf2rf <= ~actv_mux_gbf2rf;
                    end
                    if(/*~w_xor_wgt_rf1_need_delay[0]*/wgt_is_swap) begin
                        if(~wgt_rf_num) rf_wgt_buf1_send_finish <= 1'b0; else rf_wgt_buf2_send_finish <= 1'b0;
                        if(wgt_gbf_end) wgt_mux_gbf2rf <= ~wgt_mux_gbf2rf;
                    end
                    rf_actv_w_addr <= rf_actv_tm_addr[rf_tm_cycle[0]]; rf_wgt_w_addr <= rf_wgt_tm_addr[rf_tm_cycle[1]];
                    if(nxt_state != init_S3) begin
                        if(actv_rf_end) begin 
                            if(actv_rf_num)
                                rf_actv_buf2_send_finish <= 1'b1;
                            else
                                rf_actv_buf1_send_finish <= 1'b1;
                            end 
                        else begin
                            if(actv_rf_num)
                                rf_actv_buf2_send_finish <= 1'b0;
                            else
                                rf_actv_buf1_send_finish <= 1'b0;
                        end
                        if(wgt_rf_end) begin 
                            if(wgt_rf_num)
                                rf_wgt_buf2_send_finish <= 1'b1;
                            else
                                rf_wgt_buf1_send_finish <= 1'b1;
                        end 
                        else begin 
                            if(wgt_rf_num)
                                rf_wgt_buf2_send_finish <= 1'b0;
                            else
                                rf_wgt_buf1_send_finish <= 1'b0;
                        end
                    end
                    else begin
                        rf_actv_buf1_send_finish <= rf_actv_buf1_send_finish; rf_actv_buf2_send_finish <= rf_actv_buf2_send_finish;
                        rf_wgt_buf1_send_finish <= rf_wgt_buf1_send_finish; rf_wgt_buf2_send_finish <= rf_wgt_buf2_send_finish;
                    end
                    conv_finish <= 1'b0;
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns rf_actv_w_addr / rf_wgt_w_addr: %h / %d  ", $time, rf_actv_w_addr, rf_wgt_w_addr);
                    $display("%0t ns rf_actv_buf1_send_finish / rf_wgt_buf1_send_finish: %d / %d  ", $time, rf_actv_buf1_send_finish, rf_wgt_buf1_send_finish);
                    $display("%0t ns rf_actv_buf2_send_finish / rf_wgt_buf2_send_finish: %d / %d  ", $time, rf_actv_buf2_send_finish, rf_wgt_buf2_send_finish);
                end
                S3:
                begin
                    if(/*~w_xor_actv_rf1_need_delay[0]*/actv_is_swap) begin
                        if(~actv_rf_num) rf_actv_buf1_send_finish <= 1'b0; else rf_actv_buf2_send_finish <= 1'b0;
                        if(actv_gbf_end) actv_mux_gbf2rf <= ~actv_mux_gbf2rf;
                    end
                    if(/*~w_xor_wgt_rf1_need_delay[0]*/wgt_is_swap) begin
                        if(~wgt_rf_num) rf_wgt_buf1_send_finish <= 1'b0; else rf_wgt_buf2_send_finish <= 1'b0;
                        if(wgt_gbf_end) wgt_mux_gbf2rf <= ~wgt_mux_gbf2rf;
                    end
                    $display("negedge %0t ns gbf controller's cur state: S3 ", $time);
                    rf_actv_w_addr <= rf_actv_tm_addr[rf_tm_cycle[0]]; rf_wgt_w_addr <= rf_wgt_tm_addr[rf_tm_cycle[1]];
                    if(actv_rf_end) begin 
                        if(actv_rf_num)
                            rf_actv_buf2_send_finish <= 1'b1;
                        else
                            rf_actv_buf1_send_finish <= 1'b1;
                        end 
                    else begin
                        if(actv_rf_num)
                            rf_actv_buf2_send_finish <= 1'b0;
                        else
                            rf_actv_buf1_send_finish <= 1'b0;
                    end
                    if(wgt_rf_end) begin 
                        if(wgt_rf_num)
                            rf_wgt_buf2_send_finish <= 1'b1;
                        else
                            rf_wgt_buf1_send_finish <= 1'b1;
                    end 
                    else begin 
                        if(wgt_rf_num)
                            rf_wgt_buf2_send_finish <= 1'b0;
                        else
                            rf_wgt_buf1_send_finish <= 1'b0;
                    end
                    conv_finish <= 1'b0;
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns rf_actv_w_addr / rf_wgt_w_addr: %h / %d  ", $time, rf_actv_w_addr, rf_wgt_w_addr);
                    $display("%0t ns rf_actv_buf1_send_finish / rf_wgt_buf1_send_finish: %d / %d  ", $time, rf_actv_buf1_send_finish, rf_wgt_buf1_send_finish);
                    $display("%0t ns rf_actv_buf2_send_finish / rf_wgt_buf2_send_finish: %d / %d  ", $time, rf_actv_buf2_send_finish, rf_wgt_buf2_send_finish);
                end
                FINISH:
                begin
                    rf_actv_data_avail <= 1'b0; rf_wgt_data_avail <= 1'b0;
                    actv_mux_gbf2rf <= 1'bx; wgt_mux_gbf2rf <= 1'bx;
                    actv_gbf1_need_data <= 1'b1; actv_gbf2_need_data <= 1'b1; wgt_gbf1_need_data <= 1'b1; wgt_gbf2_need_data <= 1'b1;
                    rf_actv_buf1_send_finish <= 1'b0; rf_actv_buf2_send_finish <= 1'b0; rf_wgt_buf1_send_finish <= 1'b0; rf_wgt_buf2_send_finish <= 1'b0;
                    conv_finish <= 1'b1;
                end
                default:
                    ;
            endcase
        end
    end

    //posedge output : actv/wgt_gbf_addrb, actv/wgt_gbf_en1/2b, actv/wgt_mux32_addr, rf_actv/wgt_en_addr
    always @(posedge clk) begin
        if(reset) begin
            //set the output value
            actv_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}}; wgt_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}};
            actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0;
            actv_mux32_addr <= 3'bx; wgt_mux32_addr <= 3'bx;
            rf_actv_en_addr <= 3'bx; rf_wgt_en_addr <= 3'bx;
        end
        else begin
            case(nxt_state) //non-blocking assignment
                IDLE:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: IDLE ", $time);
                    actv_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}}; wgt_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}};
                    actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0;
                    actv_mux32_addr <= 3'bx; wgt_mux32_addr <= 3'bx;
                    rf_actv_en_addr <= 3'bx; rf_wgt_en_addr <= 3'bx;
                end
                delay_S1:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: delay_S1 ", $time);
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                end
                S1:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: S1 ", $time);
                    actv_gbf_addrb <= gbf_rel_cycle[0]*gbf_addr_per_rf[0]+gbf_addr_per_rf_cycle[0]; wgt_gbf_addrb <= gbf_rel_cycle[1]*gbf_addr_per_rf[1]+gbf_addr_per_rf_cycle[1];  //a*b+c
                    if(actv_rf_end) begin actv_gbf_en1b <= 1'b0; end else begin actv_gbf_en1b <= 1'b1; end actv_gbf_en2b <= 1'b0; 
                    if(wgt_rf_end) begin wgt_gbf_en1b <= 1'b0; end else begin wgt_gbf_en1b <= 1'b1; end wgt_gbf_en2b <= 1'b0;
                    actv_mux32_addr <= rf_mux32_addr_cycle[0]; wgt_mux32_addr <= rf_mux32_addr_cycle[1];
                    if(actv_rf_end) begin rf_actv_en_addr <= 3'bx; end else begin rf_actv_en_addr <= rf_en_cycle[0]; end
                    if(wgt_rf_end) begin rf_wgt_en_addr <= 3'bx; end else begin rf_wgt_en_addr <= rf_en_cycle[1]; end
                    actv_rf_end_out <= actv_rf_end; wgt_rf_end_out <= wgt_rf_end;
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_gbf_addrb / wgt_gbf_addrb: %d / %d  ", $time, actv_gbf_addrb, wgt_gbf_addrb);
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                    $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b: %d / %d  ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                    $display("%0t ns actv_mux32_addr / wgt_mux32_addr: %d / %d  ", $time, actv_mux32_addr, wgt_mux32_addr);
                    $display("%0t ns rf_actv_en_addr / rf_wgt_en_addr: %d / %d  ", $time, rf_actv_en_addr, rf_wgt_en_addr);
                end
                S2:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: S2 ", $time);
                    actv_gbf_addrb <= gbf_rel_cycle[0]*gbf_addr_per_rf[0]+gbf_addr_per_rf_cycle[0]; wgt_gbf_addrb <= gbf_rel_cycle[1]*gbf_addr_per_rf[1]+gbf_addr_per_rf_cycle[1];  //a*b+c
                    if(cur_state == S1) actv_gbf_en1b <= 1'b1; else begin if(actv_rf_end) begin actv_gbf_en1b <= 1'b0; end else begin actv_gbf_en1b <= 1'b1; end end
                    actv_gbf_en2b <= 1'b0; 
                    if(cur_state == S1) wgt_gbf_en1b <= 1'b1; else begin if(wgt_rf_end) begin wgt_gbf_en1b <= 1'b0; end else begin wgt_gbf_en1b <= 1'b1; end end
                    wgt_gbf_en2b <= 1'b0;
                    actv_mux32_addr <= rf_mux32_addr_cycle[0]; wgt_mux32_addr <= rf_mux32_addr_cycle[1];
                    if(actv_rf_end) begin rf_actv_en_addr <= 3'bx; end else begin rf_actv_en_addr <= rf_en_cycle[0]; end
                    if(wgt_rf_end) begin rf_wgt_en_addr <= 3'bx; end else begin rf_wgt_en_addr <= rf_en_cycle[1]; end
                    actv_rf_end_out <= actv_rf_end; wgt_rf_end_out <= wgt_rf_end;
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_gbf_addrb / wgt_gbf_addrb: %d / %d  ", $time, actv_gbf_addrb, wgt_gbf_addrb);
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                    $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b: %d / %d  ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                    $display("%0t ns actv_mux32_addr / wgt_mux32_addr: %d / %d  ", $time, actv_mux32_addr, wgt_mux32_addr);
                    $display("%0t ns rf_actv_en_addr / rf_wgt_en_addr: %d / %d  ", $time, rf_actv_en_addr, rf_wgt_en_addr);
                end
                init_S3:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: init_S3 ", $time);
                    /*if(actv_rf_is_used) begin
                        if(actv_gbf_num) actv_gbf_en2b <= 1'b1;
                        else actv_gbf_en1b <= 1'b1;
                    end
                    if(wgt_rf_is_used) begin
                        if(wgt_gbf_num) wgt_gbf_en2b <= 1'b1;
                        else wgt_gbf_en1b <= 1'b1;
                    end*/
                    actv_rf_end_out <= actv_rf_end; wgt_rf_end_out <= wgt_rf_end;
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_gbf_addrb / wgt_gbf_addrb: %d / %d  ", $time, actv_gbf_addrb, wgt_gbf_addrb);
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                    $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b: %d / %d  ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                    $display("%0t ns actv_mux32_addr / wgt_mux32_addr: %d / %d  ", $time, actv_mux32_addr, wgt_mux32_addr);
                    $display("%0t ns rf_actv_en_addr / rf_wgt_en_addr: %d / %d  ", $time, rf_actv_en_addr, rf_wgt_en_addr);
                end
                S3:
                begin
                    $display("posedge %0t ns gbf controller's nxt state: S3 ", $time);
                    actv_gbf_addrb <= gbf_rel_cycle[0]*gbf_addr_per_rf[0]+gbf_addr_per_rf_cycle[0]; wgt_gbf_addrb <= gbf_rel_cycle[1]*gbf_addr_per_rf[1]+gbf_addr_per_rf_cycle[1];  //a*b+c
                    /*if(actv_rf_is_used) begin
                        if(actv_gbf_num) begin
                            if(actv_rf_end) begin actv_gbf_en2b <= 1'b0; end else begin actv_gbf_en2b <= 1'b1; end actv_gbf_en1b <= 1'b0;
                        end
                        else begin
                            if(actv_rf_end) begin actv_gbf_en1b <= 1'b0; end else begin actv_gbf_en1b <= 1'b1; end actv_gbf_en2b <= 1'b0;
                        end
                        if(actv_rf_end) begin rf_actv_en_addr <= 3'bx; end else begin rf_actv_en_addr <= rf_en_cycle[0]; end
                    end
                    else begin */
                        if(actv_gbf_num)    //current usage of actv gbf buf = 2
                            if(~actv_rf_num && rf_actv_buf1_send_finish) begin //(0,1) : stop
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= 3'bx;
                            end
                            else if(~actv_rf_num && ~rf_actv_buf1_send_finish) begin //(0,0) : send data
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b1; rf_actv_en_addr <= rf_en_cycle[0];
                            end
                            else if(actv_rf_num && rf_actv_buf2_send_finish) begin //(1,1) : stop
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= 3'bx;
                            end
                            else begin
                            //else if(actv_rf_num && ~rf_actv_buf1_send_finish) begin //(1,0) : send data
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b1; rf_actv_en_addr <= rf_en_cycle[0];
                            end
                        else
                            if(~actv_rf_num && rf_actv_buf1_send_finish) begin //(0,1) : stop
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= 3'bx;
                            end
                            else if(~actv_rf_num && ~rf_actv_buf1_send_finish) begin //(0,0) : send data
                                actv_gbf_en1b <= 1'b1; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= rf_en_cycle[0];
                            end
                            else if(actv_rf_num && rf_actv_buf2_send_finish) begin //(1,1) : stop
                                actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= 3'bx;
                            end
                            else begin
                            //else if(actv_rf_num && ~rf_actv_buf1_send_finish) begin //(1,0) : send data
                                actv_gbf_en1b <= 1'b1; actv_gbf_en2b <= 1'b0; rf_actv_en_addr <= rf_en_cycle[0];
                            end
                    //end
                    /*if(wgt_rf_is_used) begin
                        if(wgt_gbf_num) begin
                            if(wgt_rf_end) begin wgt_gbf_en2b <= 1'b0; end else begin wgt_gbf_en2b <= 1'b1; end wgt_gbf_en1b <= 1'b0;
                        end
                        else begin
                            if(wgt_rf_end) begin wgt_gbf_en1b <= 1'b0; end else begin wgt_gbf_en1b <= 1'b1; end wgt_gbf_en2b <= 1'b0;
                        end
                        if(wgt_rf_end) begin rf_wgt_en_addr <= 3'bx; end else begin rf_wgt_en_addr <= rf_en_cycle[1]; end
                    end
                    else begin */
                        if(wgt_gbf_num)    //current usage of wgt gbf buf = 2
                            if(~wgt_rf_num && rf_wgt_buf1_send_finish) begin //(0,1) : stop
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= 3'bx;
                            end
                            else if(~wgt_rf_num && ~rf_wgt_buf1_send_finish) begin //(0,0) : send data
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b1; rf_wgt_en_addr <= rf_en_cycle[1];
                            end
                            else if(wgt_rf_num && rf_wgt_buf2_send_finish) begin //(1,1) : stop
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= 3'bx;
                            end
                            else begin
                            //else if(wgt_rf_num && ~rf_wgt_buf1_send_finish) begin //(1,0) : send data
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b1; rf_wgt_en_addr <= rf_en_cycle[1];
                            end
                        else
                            if(~wgt_rf_num && rf_wgt_buf1_send_finish) begin //(0,1) : stop
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= 3'bx;
                            end
                            else if(~wgt_rf_num && ~rf_wgt_buf1_send_finish) begin //(0,0) : send data
                                wgt_gbf_en1b <= 1'b1; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= rf_en_cycle[1];
                            end
                            else if(wgt_rf_num && rf_wgt_buf2_send_finish) begin //(1,1) : stop
                                wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= 3'bx;
                            end
                            else begin
                            //else if(wgt_rf_num && ~rf_wgt_buf1_send_finish) begin //(1,0) : send data
                                wgt_gbf_en1b <= 1'b1; wgt_gbf_en2b <= 1'b0; rf_wgt_en_addr <= rf_en_cycle[1];
                            end
                    //end
                    actv_mux32_addr <= rf_mux32_addr_cycle[0]; wgt_mux32_addr <= rf_mux32_addr_cycle[1];
                    actv_rf_end_out <= actv_rf_end; wgt_rf_end_out <= wgt_rf_end;
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_gbf_addrb / wgt_gbf_addrb: %d / %d  ", $time, actv_gbf_addrb, wgt_gbf_addrb);
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                    $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b: %d / %d  ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                    $display("%0t ns actv_mux32_addr / wgt_mux32_addr: %d / %d  ", $time, actv_mux32_addr, wgt_mux32_addr);
                    $display("%0t ns rf_actv_en_addr / rf_wgt_en_addr: %d / %d  ", $time, rf_actv_en_addr, rf_wgt_en_addr);
                end
                WAIT:   //nothing to change the output or register
                begin
                    $display("posedge %0t ns gbf controller's nxt state: WAIT ", $time);
                    actv_gbf_addrb <= gbf_rel_cycle[0]*gbf_addr_per_rf[0]+gbf_addr_per_rf_cycle[0]; wgt_gbf_addrb <= gbf_rel_cycle[1]*gbf_addr_per_rf[1]+gbf_addr_per_rf_cycle[1];  //a*b+c
                    if(actv_gbf_num) begin
                        if(actv_rf_end) begin actv_gbf_en2b <= 1'b0; end else begin actv_gbf_en2b <= 1'b1; end actv_gbf_en1b <= 1'b0;
                    end
                    else begin
                        if(actv_rf_end) begin actv_gbf_en1b <= 1'b0; end else begin actv_gbf_en1b <= 1'b1; end actv_gbf_en2b <= 1'b0;
                    end
                    if(wgt_gbf_num) begin
                        if(wgt_rf_end) begin wgt_gbf_en2b <= 1'b0; end else begin wgt_gbf_en2b <= 1'b1; end wgt_gbf_en1b <= 1'b0;
                    end
                    else begin
                        if(wgt_rf_end) begin wgt_gbf_en1b <= 1'b0; end else begin wgt_gbf_en1b <= 1'b1; end wgt_gbf_en2b <= 1'b0;
                    end
                    actv_mux32_addr <= rf_mux32_addr_cycle[0]; wgt_mux32_addr <= rf_mux32_addr_cycle[1];
                    if(actv_rf_end) begin rf_actv_en_addr <= 3'bx; end else begin rf_actv_en_addr <= rf_en_cycle[0]; end
                    if(wgt_rf_end) begin rf_wgt_en_addr <= 3'bx; end else begin rf_wgt_en_addr <= rf_en_cycle[1]; end
                    actv_rf_end_out <= actv_rf_end; wgt_rf_end_out <= wgt_rf_end;
                    $display("%0t ns gbf_irrel_cycle[0] / gbf_rel_cycle[0] / gbf_addr_per_rf[0] / gbf_addr_per_rf_cycle[0]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[0], gbf_rel_cycle[0], gbf_addr_per_rf[0], gbf_addr_per_rf_cycle[0]);
                    $display("%0t ns gbf_irrel_cycle[1] / gbf_rel_cycle[1] / gbf_addr_per_rf[1] / gbf_addr_per_rf_cycle[1]: %d / %d / %d / %d ", $time, gbf_irrel_cycle[1], gbf_rel_cycle[1], gbf_addr_per_rf[1], gbf_addr_per_rf_cycle[1]);
                    $display("%0t ns actv_gbf_addrb / wgt_gbf_addrb: %d / %d  ", $time, actv_gbf_addrb, wgt_gbf_addrb);
                    $display("%0t ns actv_rf_end / wgt_rf_end: %d / %d  ", $time, actv_rf_end, wgt_rf_end);
                    $display("%0t ns actv_rf_num / wgt_rf_num: %d / %d  ", $time, actv_rf_num, wgt_rf_num);
                    $display("%0t ns actv_is_swap / wgt_is_swap: %d / %d  ", $time, actv_is_swap, wgt_is_swap);
                    $display("%0t ns actv_gbf_en1b / wgt_gbf_en1b: %d / %d  ", $time, actv_gbf_en1b, wgt_gbf_en1b);
                    $display("%0t ns actv_mux32_addr / wgt_mux32_addr: %d / %d  ", $time, actv_mux32_addr, wgt_mux32_addr);
                    $display("%0t ns rf_actv_en_addr / rf_wgt_en_addr: %d / %d  ", $time, rf_actv_en_addr, rf_wgt_en_addr);
                end
                FINISH: //setting of finish will be done at posedge
                begin
                    $display("posedge %0t ns gbf controller's nxt state: FINISH ", $time);
                    actv_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}}; wgt_gbf_addrb <= {GBF_ADDR_BITWIDTH{1'bx}};
                    actv_gbf_en1b <= 1'b0; actv_gbf_en2b <= 1'b0; wgt_gbf_en1b <= 1'b0; wgt_gbf_en2b <= 1'b0;
                    actv_mux32_addr <= 3'bx; wgt_mux32_addr <= 3'bx;
                    rf_actv_en_addr <= 3'bx; rf_actv_w_addr <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    rf_wgt_en_addr <= 3'bx; rf_wgt_w_addr <= {WGT_ADDR_BITWIDTH{1'bx}};
                end
                default:
                    ;
            endcase
        end
    end

    //negedge update of the REGISTER
    always @(negedge clk) begin
        if(reset) begin
            //initialize the REGISTER
            //cycle 2
            rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}}; rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
        end
        else begin
            case(cur_state)
                IDLE, delay_S1:
                    ;
                S1:
                begin
                    //activation's loop
                    //cycle 2
                    if((rf_tm_cycle[0] < rf_tm_num[0]-1) && (~actv_rf_end))
                        if(nxt_state != S2) begin
                            $display($time, " update occured");
                            rf_tm_cycle[0] <= rf_tm_cycle[0]+1;
                        end
                        else begin
                            $display($time, " preserved");
                            rf_tm_cycle[0] <= rf_tm_cycle[0];
                        end
                    else
                        rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    //weight's loop
                    //cycle 2
                    if((rf_tm_cycle[1] < rf_tm_num[1]-1) && (~wgt_rf_end))
                        if(nxt_state != S2) begin
                            $display($time, " update occured");
                            rf_tm_cycle[1] <= rf_tm_cycle[1]+1;
                        end
                        else begin
                            $display($time, " preserved");
                            rf_tm_cycle[1] <= rf_tm_cycle[1];
                        end
                    else
                        rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    $display($time, " rf_tm_cycle[0] : %h", rf_tm_cycle[0]);
                    $display($time, " rf_tm_cycle[1] : %h", rf_tm_cycle[1]);
                end
                S2:
                begin
                    //activation's loop
                    //cycle 2
                    if((rf_tm_cycle[0] < rf_tm_num[0]-1) && (~actv_rf_end))
                        if(nxt_state != init_S3) begin
                            $display($time, " update occured");
                            rf_tm_cycle[0] <= rf_tm_cycle[0]+1;
                        end
                        else begin
                            $display($time, " preserved");
                            rf_tm_cycle[0] <= rf_tm_cycle[0];
                        end
                    else
                        rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    //weight's loop
                    //cycle 2
                    if((rf_tm_cycle[1] < rf_tm_num[1]-1) && (~wgt_rf_end))
                        if(nxt_state != init_S3) begin
                            $display($time, " update occured");
                            rf_tm_cycle[1] <= rf_tm_cycle[1]+1;
                        end
                        else begin
                            $display($time, " preserved");
                            rf_tm_cycle[1] <= rf_tm_cycle[1];
                        end
                    else
                        rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    $display($time, " rf_tm_cycle[0] : %h", rf_tm_cycle[0]);
                    $display($time, " rf_tm_cycle[1] : %h", rf_tm_cycle[1]);
                end
                WAIT:
                begin
                    //activation's loop
                    //cycle 2
                    if((rf_tm_cycle[0] < rf_tm_num[0]-1) && (~actv_rf_end) /*&& w_xor_actv_rf1_need_delay[0]*/ && ~actv_is_swap && ~actv_is_swap2)
                        if(nxt_state != init_S3) begin
                            $display($time, " tm[0] update occured");
                            rf_tm_cycle[0] <= rf_tm_cycle[0]+1;
                        end
                        else begin
                            $display($time, " tm[0] preserved");
                            rf_tm_cycle[0] <= rf_tm_cycle[0];
                        end
                    else
                        rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    //weight's loop
                    //cycle 2
                    if((rf_tm_cycle[1] < rf_tm_num[1]-1) && (~wgt_rf_end) /*&& w_xor_wgt_rf1_need_delay[0]*/ && ~wgt_is_swap && ~wgt_is_swap2)
                        if(nxt_state != init_S3) begin
                            $display($time, " tm[1] update occured");
                            rf_tm_cycle[1] <= rf_tm_cycle[1]+1;
                        end
                        else begin
                            $display($time, " tm[1] preserved");
                            rf_tm_cycle[1] <= rf_tm_cycle[1];
                        end
                    else
                        rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    $display($time, " rf_tm_cycle[0] : %h", rf_tm_cycle[0]);
                    $display($time, " rf_tm_cycle[1] : %h", rf_tm_cycle[1]);
                    $display($time, " actv_is_swap, wgt_is_swap : %d %d", actv_is_swap, wgt_is_swap);
                end
                init_S3:
                begin
                    if(((~actv_rf_num && ~rf_actv_buf1_send_finish)||(actv_rf_num && ~rf_actv_buf2_send_finish)))
                        if((rf_tm_cycle[0] < rf_tm_num[0]-1) && (~actv_rf_end) /*&& w_xor_actv_rf1_need_delay[0]*/ && ~actv_is_swap && ~actv_is_swap2)
                            rf_tm_cycle[0] <= rf_tm_cycle[0]+1;
                        else
                            rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    else
                        rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    if(((~wgt_rf_num && ~rf_wgt_buf1_send_finish)||(wgt_rf_num && ~rf_wgt_buf2_send_finish)))
                        if((rf_tm_cycle[1] < rf_tm_num[1]-1) && (~wgt_rf_end) /*&& w_xor_wgt_rf1_need_delay[0]*/ && ~wgt_is_swap && ~wgt_is_swap2)
                            rf_tm_cycle[1] <= rf_tm_cycle[1]+1;
                        else
                            rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    else
                        rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    $display($time, " rf_tm_cycle[0] : %h", rf_tm_cycle[0]);
                    $display($time, " rf_tm_cycle[1] : %h", rf_tm_cycle[1]);
                end
                S3:
                begin
                    //activation's loop
                    //cycle 2
                    if(((~actv_rf_num && ~rf_actv_buf1_send_finish)||(actv_rf_num && ~rf_actv_buf2_send_finish)))
                        if((rf_tm_cycle[0] < rf_tm_num[0]-1) && (~actv_rf_end) /*&& w_xor_actv_rf1_need_delay[0]*/ && ~actv_is_swap && ~actv_is_swap2)
                            rf_tm_cycle[0] <= rf_tm_cycle[0]+1;
                        else
                            rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    else
                        rf_tm_cycle[0] <= {max_tm_cycle_bitwidth{1'b0}};
                    
                    //weight's loop
                    //cycle 2
                    if(((~wgt_rf_num && ~rf_wgt_buf1_send_finish)||(wgt_rf_num && ~rf_wgt_buf2_send_finish)))
                        if((rf_tm_cycle[1] < rf_tm_num[1]-1) && (~wgt_rf_end) /*&& w_xor_wgt_rf1_need_delay[0]*/ && ~wgt_is_swap && ~wgt_is_swap2)
                            rf_tm_cycle[1] <= rf_tm_cycle[1]+1;
                        else
                            rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    else
                        rf_tm_cycle[1] <= {max_tm_cycle_bitwidth{1'b0}};
                    $display($time, " rf_tm_cycle[0] : %h", rf_tm_cycle[0]);
                    $display($time, " rf_tm_cycle[1] : %h", rf_tm_cycle[1]);
                end
                default:
                    ;
            endcase
        end
    end

    reg flag;
    localparam max_delay = 1;
    reg [1:0] delay[0:1];
    //posedge update of the REGISTER
    always @(posedge clk) begin
        if(reset) begin
            //initialize the REGISTER
            gbf_rel_cycle[0] <= {max_rel_bitwdith{1'b0}}; gbf_rel_cycle[1] <= {max_rel_bitwdith{1'b0}};
            gbf_irrel_cycle[0]  <= {max_rel_bitwdith{1'b0}}; gbf_irrel_cycle[1]  <= {max_rel_bitwdith{1'b0}}; 
            gbf_per_tm_cycle[0] <= 3'b0; gbf_per_tm_cycle[1] <= 3'b0;
            gbf_addr_per_rf_cycle[0] <= 6'b0; gbf_addr_per_rf_cycle[1] <= 6'b0;
            //cycle 3
            rf_mux32_addr_cycle[0] <= 3'b0; rf_mux32_addr_cycle[1] <= 3'b0;
            //cycle 4
            rf_en_cycle[0] <= 3'b0; rf_en_cycle[1] <= 3'b0;
            /*REGISTER FOR CHECKPOINT*/
            actv_rf_end <= 1'b1; wgt_rf_end <= 1'b1;
            actv_gbf_num <= 1'b0; wgt_gbf_num <= 1'b0;
            actv_gbf_end <= 1'b0; wgt_gbf_end <= 1'b0;
            delay[0] <= 2'b0; delay[1] <= 2'b0;
        end
        else begin
            case(nxt_state)
                IDLE, delay_S1:
                begin
                    actv_rf_end <= 1'b0; wgt_rf_end <= 1'b0;
                end
                S1, S2, WAIT:
                begin
                    if(/*~w_xor_actv_rf1_need_data*/actv_is_swap) begin
                        actv_rf_end <= 1'b0;
                    end
                    if(/*~w_xor_wgt_rf1_need_data*/wgt_is_swap) begin
                        wgt_rf_end <= 1'b0;
                    end
                    //activation's loop
                    //cycle 1
                    if(~actv_rf_end) begin
                        if(gbf_per_tm_cycle[0] < gbf_per_tm_num[0]-1) begin
                            gbf_per_tm_cycle[0] <= gbf_per_tm_cycle[0]+1;
                        end
                        else begin
                            gbf_per_tm_cycle[0] <= 3'b0;
                            if(gbf_addr_per_rf_cycle[0] < gbf_addr_per_rf[0]-1) begin
                                gbf_addr_per_rf_cycle[0] <= gbf_addr_per_rf_cycle[0]+1;
                            end
                            else begin
                                if(delay[0] < max_delay) begin
                                    delay[0]<=delay[0]+1;
                                end
                                else begin
                                    gbf_addr_per_rf_cycle[0] <= 6'b0;
                                    if(gbf_rel_cycle[0] < gbf_rel_num[0]-1) begin
                                        gbf_rel_cycle[0] <= gbf_rel_cycle[0]+1;
                                    end
                                    else begin
                                        gbf_rel_cycle[0] <= {max_rel_bitwdith{1'b0}};
                                        if(gbf_irrel_cycle[0] < gbf_irrel_num[0]-1) begin
                                            gbf_irrel_cycle[0] <= gbf_irrel_cycle[0]+1;
                                        end
                                        else begin
                                            gbf_irrel_cycle[0] <= {max_rel_bitwdith{1'b0}};
                                            actv_gbf_end <= 1'b1;    // time to change the gbf buffer
                                            actv_gbf_num <= ~actv_gbf_num;   // swap the gbf buffer number in use
                                        end
                                    end
                                    actv_rf_end <= 1'b1;    // register buffer is filled out at this point
                                    delay[0]<=2'b0;
                                end
                            end
                        end
                    end
                    //cycle 3
                    if((rf_mux32_addr_cycle[0] < rf_mux32_addr_cycle_num[0]-1) && (~actv_rf_end))
                        rf_mux32_addr_cycle[0] <= rf_mux32_addr_cycle[0]+1;
                    else
                        rf_mux32_addr_cycle[0] <= 3'b0;
                    //cycle 4
                    if((rf_en_cycle[0] < rf_en_cycle_num[0]-1) && (~actv_rf_end))
                        rf_en_cycle[0] <= rf_en_cycle[0]+1;
                    else
                        rf_en_cycle[0] <= 3'b0;
                    
                    //weight's loop
                    //cycle 1
                    if(~wgt_rf_end) begin
                        if(gbf_per_tm_cycle[1] < gbf_per_tm_num[1]-1) begin
                            gbf_per_tm_cycle[1] <= gbf_per_tm_cycle[1]+1;
                        end
                        else begin
                            gbf_per_tm_cycle[1] <= 3'b0;
                            if(gbf_addr_per_rf_cycle[1] < gbf_addr_per_rf[1]-1) begin
                                gbf_addr_per_rf_cycle[1] <= gbf_addr_per_rf_cycle[1]+1;
                            end
                            else begin
                                if(delay[1] < max_delay) begin
                                    delay[1]<=delay[1]+1;
                                end
                                else begin
                                    gbf_addr_per_rf_cycle[1] <= 6'b0;
                                    if(gbf_rel_cycle[1] < gbf_rel_num[1]-1) begin
                                        gbf_rel_cycle[1] <= gbf_rel_cycle[1]+1;
                                    end
                                    else begin
                                        gbf_rel_cycle[1] <= {max_rel_bitwdith{1'b0}};
                                        if(gbf_irrel_cycle[1] < gbf_irrel_num[1]-1) begin
                                            gbf_irrel_cycle[1] <= gbf_irrel_cycle[1]+1;
                                        end
                                        else begin
                                            gbf_irrel_cycle[1] <= {max_rel_bitwdith{1'b0}};
                                            wgt_gbf_end <= 1'b1;    // time to change the gbf buffer
                                            wgt_gbf_num <= ~wgt_gbf_num;   // swap the gbf buffer number in use
                                        end
                                    end
                                    wgt_rf_end <= 1'b1;    // register buffer is filled out at this point
                                    delay[1]<=2'b0;
                                end
                            end
                        end
                    end
                    //cycle 3
                    if((rf_mux32_addr_cycle[1] < rf_mux32_addr_cycle_num[1]-1) && (~wgt_rf_end))
                        rf_mux32_addr_cycle[1] <= rf_mux32_addr_cycle[1]+1;
                    else
                        rf_mux32_addr_cycle[1] <= 3'b0;
                    //cycle 4
                    if((rf_en_cycle[1] < rf_en_cycle_num[1]-1) && (~wgt_rf_end))
                        rf_en_cycle[1] <= rf_en_cycle[1]+1;
                    else
                        rf_en_cycle[1] <= 3'b0;
                end
                init_S3:    //do not update the cycle
                begin
                    if(/*~w_xor_actv_rf1_need_data*/actv_is_swap) begin
                        actv_rf_end <= 1'b0;
                    end
                    if(/*~w_xor_wgt_rf1_need_data*/wgt_is_swap) begin
                        wgt_rf_end <= 1'b0;
                    end
                    gbf_per_tm_cycle[0] <= gbf_per_tm_cycle[0]; gbf_addr_per_rf_cycle[0] <= gbf_addr_per_rf_cycle[0];
                    gbf_rel_cycle[0] <= gbf_rel_cycle[0]; gbf_irrel_cycle[0] <= gbf_irrel_cycle[0];
                    rf_mux32_addr_cycle[0] <= rf_mux32_addr_cycle[0]; rf_en_cycle[0] <= rf_en_cycle[0];
                    gbf_per_tm_cycle[1] <= gbf_per_tm_cycle[1]; gbf_addr_per_rf_cycle[1] <= gbf_addr_per_rf_cycle[1];
                    gbf_rel_cycle[1] <= gbf_rel_cycle[1]; gbf_irrel_cycle[1] <= gbf_irrel_cycle[1];
                    rf_mux32_addr_cycle[1] <= rf_mux32_addr_cycle[1]; rf_en_cycle[1] <= rf_en_cycle[1];
                    flag <= 1'b1;
                end
                S3:
                begin
                    //Since init_S3's negedge, posedge scheme do not work well, S3 need flag to act like init_S3
                    if(flag) begin
                        actv_gbf_end <= 1'b0; wgt_gbf_end <= 1'b0;
                        flag <= 1'b0;
                    end
                    if(/*~w_xor_actv_rf1_need_data*/actv_is_swap) begin
                        actv_rf_end <= 1'b0;
                    end
                    if(/*~w_xor_wgt_rf1_need_data*/wgt_is_swap) begin
                        wgt_rf_end <= 1'b0;
                    end
                    //activation's loop
                    if(((~actv_rf_num && ~rf_actv_buf1_send_finish)||(actv_rf_num && ~rf_actv_buf2_send_finish))) begin
                        //cycle 1
                        if(~actv_rf_end) begin
                            if(gbf_per_tm_cycle[0] < gbf_per_tm_num[0]-1) begin
                                gbf_per_tm_cycle[0] <= gbf_per_tm_cycle[0]+1;
                            end
                            else begin
                                gbf_per_tm_cycle[0] <= 3'b0;
                                if(gbf_addr_per_rf_cycle[0] < gbf_addr_per_rf[0]-1) begin
                                    gbf_addr_per_rf_cycle[0] <= gbf_addr_per_rf_cycle[0]+1;
                                end
                                else begin
                                    if(delay[0] < max_delay) begin
                                        delay[0]<=delay[0]+1;
                                    end
                                    else begin
                                        gbf_addr_per_rf_cycle[0] <= 6'b0;
                                        if(gbf_rel_cycle[0] < gbf_rel_num[0]-1) begin
                                            gbf_rel_cycle[0] <= gbf_rel_cycle[0]+1;
                                        end
                                        else begin
                                            gbf_rel_cycle[0] <= {max_rel_bitwdith{1'b0}};
                                            if(gbf_irrel_cycle[0] < gbf_irrel_num[0]-1) begin
                                                gbf_irrel_cycle[0] <= gbf_irrel_cycle[0]+1;
                                            end
                                            else begin
                                                gbf_irrel_cycle[0] <= {max_rel_bitwdith{1'b0}};
                                                actv_gbf_end <= 1'b1;    // time to change the gbf buffer
                                                actv_gbf_num <= ~actv_gbf_num;   // swap the gbf buffer number in use
                                            end
                                        end
                                        actv_rf_end <= 1'b1;    // register buffer is filled out at this point
                                        delay[0] <= 2'b0;
                                    end
                                end
                            end
                        end
                        //cycle 3
                        if((rf_mux32_addr_cycle[0] < rf_mux32_addr_cycle_num[0]-1) && (~actv_rf_end))
                            rf_mux32_addr_cycle[0] <= rf_mux32_addr_cycle[0]+1;
                        else
                            rf_mux32_addr_cycle[0] <= 3'b0;
                        //cycle 4
                        if((rf_en_cycle[0] < rf_en_cycle_num[0]-1) && (~actv_rf_end))
                            rf_en_cycle[0] <= rf_en_cycle[0]+1;
                        else
                            rf_en_cycle[0] <= 3'b0;
                    end
                    
                    //weight's loop
                    if(((~wgt_rf_num && ~rf_wgt_buf1_send_finish)||(wgt_rf_num && ~rf_wgt_buf2_send_finish))) begin
                        //cycle 1
                        if(~wgt_rf_end) begin
                            if(gbf_per_tm_cycle[1] < gbf_per_tm_num[1]-1) begin
                                gbf_per_tm_cycle[1] <= gbf_per_tm_cycle[1]+1;
                            end
                            else begin
                                gbf_per_tm_cycle[1] <= 3'b0;
                                if(gbf_addr_per_rf_cycle[1] < gbf_addr_per_rf[1]-1) begin
                                    gbf_addr_per_rf_cycle[1] <= gbf_addr_per_rf_cycle[1]+1;
                                end
                                else begin
                                    if(delay[1] < max_delay) begin
                                        delay[1]<=delay[1]+1;
                                    end
                                    else begin
                                        gbf_addr_per_rf_cycle[1] <= 6'b0;
                                        $display("%0t ns wgt_gbf_rel_cyle: %d ", $time, gbf_rel_cycle[1]);
                                        if(gbf_rel_cycle[1] < gbf_rel_num[1]-1) begin
                                            gbf_rel_cycle[1] <= gbf_rel_cycle[1]+1;
                                        end
                                        else begin
                                            $display("%0t ns wgt_gbf_irrel_cyle: %d ", $time, gbf_irrel_cycle[1]);
                                            gbf_rel_cycle[1] <= {max_rel_bitwdith{1'b0}};
                                            if(gbf_irrel_cycle[1] < gbf_irrel_num[1]-1) begin
                                                gbf_irrel_cycle[1] <= gbf_irrel_cycle[1]+1;
                                            end
                                            else begin
                                                gbf_irrel_cycle[1] <= {max_rel_bitwdith{1'b0}};
                                                wgt_gbf_end <= 1'b1;    // time to change the gbf buffer
                                                wgt_gbf_num <= ~wgt_gbf_num;   // swap the gbf buffer number in use
                                            end
                                        end
                                        wgt_rf_end <= 1'b1;    // register buffer is filled out at this point
                                        delay[1]<=2'b0;
                                    end
                                end
                            end
                        end
                        //cycle 3
                        if((rf_mux32_addr_cycle[1] < rf_mux32_addr_cycle_num[1]-1) && (~wgt_rf_end))
                            rf_mux32_addr_cycle[1] <= rf_mux32_addr_cycle[1]+1;
                        else
                           rf_mux32_addr_cycle[1] <= 3'b0;
                        //cycle 4
                        if((rf_en_cycle[1] < rf_en_cycle_num[1]-1) && (~wgt_rf_end))
                            rf_en_cycle[1] <= rf_en_cycle[1]+1;
                        else
                            rf_en_cycle[1] <= 3'b0;
                    end
                end
                default:
                    ;
            endcase
        end
    end

endmodule