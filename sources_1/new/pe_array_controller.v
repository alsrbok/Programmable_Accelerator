//------------------------------------------------------------+
// Project: Programmable Accelerator
// Module: pe_array_controller
// Description:
//		It is a pe_array_controller which generate addr and en/we signal    
//      It communicates with actv/wgt cotnroller, and psum_su_adder in order to generate addr and signals in correct order
//      It needs meta-data about temporal mapping on register file level.
//
// History: 2022.08.30 by Min-Gyu Park (alsrbok@snu.ac.kr)
//------------------------------------------------------------+

module pe_array_controller #(parameter ROW         = 16,   //PE array row size
            parameter COL                   = 16,   //PE array column size
            parameter IN_BITWIDTH           = 8,   //For activation. weight
            parameter OUT_BITWIDTH          = 16,   //For psum
            parameter ACTV_ADDR_BITWIDTH    = 2,   //Decide rf_input memory size
            parameter ACTV_DEPTH            = 4,    //ACTV_DEPTH = 2^(ACTV_ADDR_BITWIDTH)
            parameter WGT_ADDR_BITWIDTH     = 2,
            parameter WGT_DEPTH             = 4,
            parameter PSUM_ADDR_BITWIDTH    = 2,
            parameter PSUM_DEPTH            = 4)
          ( input clk, reset, finish,                   // reset for the initial start , finish for the end of overall computation
            input actv_data_avail, wgt_data_avail, actv_buf1_send_finish, actv_buf2_send_finish, wgt_buf1_send_finish, wgt_buf2_send_finish, 
            input su_add_finish,                        // reg file do not care which buffer on psum gbf accumulate the data (Signal from the psum_su_adder module)
            output reg actv_rf1_need_data, actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data,    //This signal will send to actv/wgt gbf and trigger the transfer & select the correct rf to write 
            output reg pe_psum_finish,                  // send to psum_su_adder to initialize the su add. (guarantee the psum_out value)
            output reg conv_finish,                     // Overall computation is finished
            //input signal for PE_new_array = output signal of control logic
            output reg [ROW*COL-1:0] MAC_en,
            output reg actv_sel, output reg [ACTV_ADDR_BITWIDTH-1:0] actv_r_addr1, actv_r_addr2,
            output reg wgt_sel, output reg [WGT_ADDR_BITWIDTH-1:0] wgt_r_addr1, wgt_r_addr2,
            output reg psum_en, output reg [PSUM_ADDR_BITWIDTH-1:0] psum_addr1, psum_addr2, psum_write_addr,
            output reg turn_off     //send it to gbf_controller, su_adder to let them know when to turn off the finish signal
    );

    localparam max_rf_tm_cycle = 256;   //maximum supported number of tm cycle on register file level
    localparam bits_for_cycle = 8;      //2^(bits_for_cycle) = max_rf_tm_cycle
    
    //meta-data
    reg [bits_for_cycle-1 : 0] cycle_num[0 : 2]; // [0] : actv , [1] : wgt, [2] : psum
    reg [ACTV_ADDR_BITWIDTH-1 : 0] actv_tm_addr[0 : max_rf_tm_cycle-1]; // address cycle for activation register file 
    reg [WGT_ADDR_BITWIDTH-1 : 0] wgt_tm_addr[0 : max_rf_tm_cycle-1];
    reg [PSUM_ADDR_BITWIDTH-1 : 0] psum_tm_addr[0 : max_rf_tm_cycle-1];
    reg [ROW*COL-1:0]su_en[0:1]; //[0] : information of su, [1] : dummy for making it as memory

    //register to count the cycle
    reg [bits_for_cycle-1 : 0] cycle[0 : 2]; // [0] : actv , [1] : wgt, [2] : psum

    //register for check the end of the cycle
    reg actv_flag, wgt_flag, psum_flag;

    always @(posedge reset) begin
        if(reset) begin //reset become 1 when one layer start to being computed == update the meta data
            $display("intialize the meta data for pe array controller ");
            $readmemh("pe_array_cycle_bit_num.mem", cycle_num);
            $readmemb("pe_array_actv_tm_addr.mem", actv_tm_addr);
            $readmemb("pe_array_wgt_tm_addr.mem", wgt_tm_addr);
            $readmemb("pe_array_psum_tm_addr.mem", psum_tm_addr);
            $readmemb("pe_array_su_en.mem", su_en);

            $display("check the initialization");
            $display("cycle_num: [0]=%d / [1]=%d / [2]=%d", cycle_num[0], cycle_num[1], cycle_num[2]);
            $display("actv_tm_addr: %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d / %d %d %d %d %d %d %d %d /", actv_tm_addr[0], actv_tm_addr[1], actv_tm_addr[2], actv_tm_addr[3], actv_tm_addr[4], actv_tm_addr[5], actv_tm_addr[6], actv_tm_addr[7], actv_tm_addr[8], actv_tm_addr[9], actv_tm_addr[10], actv_tm_addr[11], actv_tm_addr[12], actv_tm_addr[13], actv_tm_addr[14], actv_tm_addr[15] , actv_tm_addr[16], actv_tm_addr[17], actv_tm_addr[18], actv_tm_addr[19], actv_tm_addr[20], actv_tm_addr[21], actv_tm_addr[22], actv_tm_addr[23], actv_tm_addr[24], actv_tm_addr[25], actv_tm_addr[26], actv_tm_addr[27], actv_tm_addr[28], actv_tm_addr[29], actv_tm_addr[30], actv_tm_addr[31]);
            $display("wgt_tm_addr: %d %d %d %d %d %d %d %d", wgt_tm_addr[0], wgt_tm_addr[1], wgt_tm_addr[2], wgt_tm_addr[3], wgt_tm_addr[4], wgt_tm_addr[5], wgt_tm_addr[6], wgt_tm_addr[7]);
            $display("psum_tm_addr: %d %d %d %d %d %d %d %d", psum_tm_addr[0], psum_tm_addr[1], psum_tm_addr[2], psum_tm_addr[3], psum_tm_addr[4], psum_tm_addr[5], psum_tm_addr[6], psum_tm_addr[7]);
            $display("su_en: %b", su_en[0]);
        end
    end

    
    localparam [2:0]
        IDLE        =  3'b000,  // Initially begin to compute new layer (nothing happen to pe array)
        S1          =  3'b001,  // actv/wgt_rf buffer1 get data from actv/wgt_gbf buffer1
        S2          =  3'b010,  // actv/wgt/psum_rf buffer1 are used in MAC operation , actv/wgt_rf buffer2 get data from actv/wgt_gbf(** If gbf send data..)
        WAIT        =  3'b011,
        init_S3     =  3'b100,  // cycle of actv or/and wgt or/and psum is/are done == trigger_signal on :: flip the usage of actv or/and wgt or/and psum buffer
        delay_S3    =  3'b101,
        S3          =  3'b110,
        FINISH      =  3'b111;

    reg [2:0] cur_state, nxt_state;
    
    /*
    parameter [3:0]
        IDLE    =  4'b0000,  // Initially begin to compute new layer (nothing happen to pe array)
        S1      =  4'b0001,  // actv/wgt_rf buffer1 get data from actv/wgt_gbf buffer1
        S2      =  4'b0010,  // actv/wgt/psum_rf buffer1 are used in MAC operation , actv/wgt_rf buffer2 get data from actv/wgt_gbf(** If gbf send data..)
        S3      =  4'b0011,
        S4      =  4'b0100,
        S5      =  4'b0101,
        S6      =  4'b0110,
        S7      =  4'b0111,
        S8      =  4'b1000,
        S9      =  4'b1001,
        FINISH  =  4'b1010;  
    reg [3:0] cur_state, nxt_state;
    */
    // transition of state
    always @(negedge clk) begin
        if(reset) begin
            cur_state <= IDLE;
            //nxt_state <= IDLE;
        end
        else
            cur_state <= nxt_state;
    end

    always @(posedge clk) begin
        //nxt_state = 3'bx;
        case(cur_state)
            IDLE:
                if(actv_data_avail || wgt_data_avail) begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to S1 from IDLE", $time);
                    nxt_state <= S1;
                end
                else   
                    nxt_state <= IDLE;
            S1:
                if(actv_buf1_send_finish && wgt_buf1_send_finish) begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to S2 from S1", $time);
                    nxt_state <= S2;
                end
                else
                    nxt_state <= S1;
            S2:
            begin
                if(actv_flag==1'b0 && wgt_flag==1'b0 && psum_flag==1'b0) begin
                    nxt_state <= S2;
                end
                else if((actv_flag==1'b1 && actv_buf2_send_finish==1'b0) || (wgt_flag==1'b1 && wgt_buf2_send_finish==1'b0) || (psum_flag==1'b1 && su_add_finish==1'b0)) begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to WAIT from S2 ", $time);
                    nxt_state <= WAIT;
                end
                else if((!actv_flag || actv_buf2_send_finish) && (!wgt_flag || wgt_buf2_send_finish) && (!psum_flag || su_add_finish)) begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to init S3 from S2", $time);
                    $display("%0t ns pe_array_controller: actv_flag /actv_buf1_send_finish /actv_buf2_send_finish /wgt_flag /wgt_buf1_send_finish /wgt_buf2_send_finish /psum_flag /su_add_finish : %d /%d /%d /%d /%d /%d /%d /%d ", $time,actv_flag ,actv_buf1_send_finish ,actv_buf2_send_finish ,wgt_flag ,wgt_buf1_send_finish ,wgt_buf2_send_finish ,psum_flag ,su_add_finish);
                    nxt_state <= init_S3;
                end
                else begin
                    nxt_state <= S2;
                end
            end
            WAIT:
            begin
                if((!actv_flag || (actv_rf1_need_data && actv_buf1_send_finish) || (actv_rf2_need_data && actv_buf2_send_finish)) && (!wgt_flag || (wgt_rf1_need_data && wgt_buf1_send_finish) || (wgt_rf2_need_data && wgt_buf2_send_finish)) && (!psum_flag || su_add_finish)) begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to init S3 from WAIT", $time);
                    $display("%0t ns pe_array_controller: actv_flag /actv_buf1_send_finish /actv_buf2_send_finish /wgt_flag /wgt_buf1_send_finish /wgt_buf2_send_finish /psum_flag /su_add_finish : %d /%d /%d /%d /%d /%d /%d /%d ", $time,actv_flag ,actv_buf1_send_finish ,actv_buf2_send_finish ,wgt_flag ,wgt_buf1_send_finish ,wgt_buf2_send_finish ,psum_flag ,su_add_finish);
                    nxt_state <= init_S3;
                end
                else begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to WAIT from WAIT", $time);
                    $display("%0t ns pe_array_controller: actv_flag /actv_buf1_send_finish /actv_buf2_send_finish /wgt_flag /wgt_buf1_send_finish /wgt_buf2_send_finish /psum_flag /su_add_finish : %d /%d /%d /%d /%d /%d /%d /%d ", $time,actv_flag ,actv_buf1_send_finish ,actv_buf2_send_finish ,wgt_flag ,wgt_buf1_send_finish ,wgt_buf2_send_finish ,psum_flag ,su_add_finish);  
                    nxt_state <= WAIT;
                end
            end
            init_S3:
                if(finish)
                    nxt_state <= FINISH;
                else begin
                    $display("%0t ns pe_array_controller's nxt stage is setting to delay S3 from init_S3", $time);
                    nxt_state <= delay_S3;
                end
            delay_S3:
                if(finish)
                    nxt_state <= FINISH;
                else
                    nxt_state <= S3;
            S3:
                if(finish)
                    nxt_state <= FINISH;
                else begin
                    if(~actv_flag && ~wgt_flag && ~psum_flag) begin
                        nxt_state <= S3;
                    end
                    else if((actv_flag && ((actv_rf1_need_data && ~actv_buf1_send_finish) || (actv_rf2_need_data && ~actv_buf2_send_finish))) || (wgt_flag && ((wgt_rf1_need_data && ~wgt_buf1_send_finish) || (wgt_rf2_need_data && ~wgt_buf2_send_finish))) || (psum_flag && ~su_add_finish)) begin
                        $display("%0t ns pe_array_controller's nxt stage is setting to WAIT from S3 ", $time);
                        $display("%0t ns pe_array_controller: actv_flag /actv_buf1_send_finish /actv_buf2_send_finish /wgt_flag /wgt_buf1_send_finish /wgt_buf2_send_finish /psum_flag /su_add_finish : %d /%d /%d /%d /%d /%d /%d /%d ", $time,actv_flag ,actv_buf1_send_finish ,actv_buf2_send_finish ,wgt_flag ,wgt_buf1_send_finish ,wgt_buf2_send_finish ,psum_flag ,su_add_finish);
                        $display("%0t ns pe_array_controller: actv_rf1_need_data / actv_rf2_need_data / wgt_rf1_need_data / wgt_rf2_need_data : %d / %d / %d / $d", $time, actv_rf1_need_data ,actv_rf2_need_data, wgt_rf1_need_data, wgt_rf2_need_data);
                        nxt_state <= WAIT;
                    end
                    else if((!actv_flag || (actv_rf1_need_data && actv_buf1_send_finish) || (actv_rf2_need_data && actv_buf2_send_finish)) && (!wgt_flag || (wgt_rf1_need_data && wgt_buf1_send_finish) || (wgt_rf2_need_data && wgt_buf2_send_finish)) && (!psum_flag || su_add_finish)) begin
                        $display("%0t ns pe_array_controller's nxt stage is setting to init S3 from 32", $time);
                        $display("%0t ns pe_array_controller: actv_flag /actv_buf1_send_finish /actv_buf2_send_finish /wgt_flag /wgt_buf1_send_finish /wgt_buf2_send_finish /psum_flag /su_add_finish : %d /%d /%d /%d /%d /%d /%d /%d ", $time,actv_flag ,actv_buf1_send_finish ,actv_buf2_send_finish ,wgt_flag ,wgt_buf1_send_finish ,wgt_buf2_send_finish ,psum_flag ,su_add_finish);
                        nxt_state <= init_S3;
                    end
                    else
                        nxt_state <= S3;
                end
            FINISH:
                nxt_state <= FINISH;
            default:
                nxt_state <= IDLE;
        endcase
    end

    reg check_flag[0:2];

    // at each state, send output on the negedge clk.
    always @(negedge clk) begin
            case(nxt_state) //due to non-blocking assignmet
                IDLE:
                begin
                    $display("%0t ns pe_array_controller's nxt state: IDLE ", $time);
                    actv_rf1_need_data <= 1'b1; actv_rf2_need_data <= 1'b1; wgt_rf1_need_data <= 1'b1; wgt_rf2_need_data <= 1'b1;
                    pe_psum_finish <= 1'b0;
                    conv_finish <= 1'b0;
                    MAC_en <= {ROW*COL{1'b0}};
                    actv_sel <= 1'bx; actv_r_addr1 <= {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    wgt_sel <= 1'bx; wgt_r_addr1 <= {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}};
                    psum_en <= 1'bx; psum_addr1 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_write_addr <= {PSUM_ADDR_BITWIDTH{1'bx}};
                end 
                S1:
                begin
                    $display("%0t ns pe_array_controller's nxt state: S1 ", $time);
                    actv_rf1_need_data <= 1'b1; actv_rf2_need_data <= 1'b1; wgt_rf1_need_data <= 1'b1; wgt_rf2_need_data <= 1'b1;
                    //if(actv_buf1_send_finish) begin actv_rf1_need_data <= 1'b0; end else begin actv_rf1_need_data <= 1'b1; end actv_rf2_need_data <= 1'b1; 
                    //if(wgt_buf1_send_finish) begin wgt_rf1_need_data <= 1'b0; end else begin wgt_rf1_need_data <= 1'b1; end wgt_rf2_need_data <= 1'b1;
                    pe_psum_finish <= 1'b0;
                    conv_finish <= 1'b0;
                    MAC_en <= {ROW*COL{1'b0}};
                    actv_sel <= 1'b1; actv_r_addr1 <= {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    wgt_sel <= 1'b1; wgt_r_addr1 <= {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}};
                    psum_en <= 1'bx; psum_addr1 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_write_addr <= {PSUM_ADDR_BITWIDTH{1'bx}};
                end
                S2:
                begin
                    $display("%0t ns pe_array_controller's nxt state: S2 ", $time);
                    actv_rf1_need_data <= 1'b0; actv_rf2_need_data <= 1'b1; wgt_rf1_need_data <= 1'b0; wgt_rf2_need_data <= 1'b1;
                    pe_psum_finish <= 1'b0;
                    conv_finish <= 1'b0;
                    MAC_en <= su_en[0];
                    actv_sel <= 1'b0; actv_r_addr1 <= actv_tm_addr[cycle[0]]; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    wgt_sel <= 1'b0; wgt_r_addr1 <= wgt_tm_addr[cycle[1]]; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}};
                    psum_en <= 1'b1; psum_addr1 <= psum_tm_addr[cycle[2]]; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_write_addr <= psum_tm_addr[cycle[2]];
                    $display("%0t ns cycle[0], [1], [2]: %d / %d / %d ", $time, cycle[0], cycle[1], cycle[2]);
                    $display("%0t ns actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr: %d / %d / %d / %d", $time, actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr);
                end
                WAIT:
                begin
                    $display("%0t ns pe_array_controller's nxt state: WAIT ", $time);
                    pe_psum_finish <= 1'b0;
                    MAC_en <= {ROW*COL{1'b0}};  //hold the data and signal
                end
                init_S3:    // just for change the signal. do not compute or increase the addr(cycle)
                begin
                    $display("%0t ns pe_array_controller's nxt state: init_S3 ", $time);
                    MAC_en <= {ROW*COL{1'b0}};
                    if(actv_flag && ((actv_rf1_need_data && actv_buf1_send_finish) || (actv_rf2_need_data && actv_buf2_send_finish))) begin
                        $display("actv info changed at negedge");
                        check_flag[0] <= 1'b1;
                        actv_rf1_need_data <= ~actv_rf1_need_data; actv_rf2_need_data <= ~actv_rf2_need_data;
                        actv_sel <= ~actv_sel;
                    end
                    if(wgt_flag && ((wgt_rf1_need_data && wgt_buf1_send_finish) || (wgt_rf2_need_data && wgt_buf2_send_finish))) begin
                        $display("wgt info changed at negedge");
                        check_flag[1] <= 1'b1;
                        wgt_rf1_need_data <= ~wgt_rf1_need_data; wgt_rf2_need_data <= ~wgt_rf2_need_data;
                        wgt_sel <= ~ wgt_sel;
                    end

                    if(psum_flag && su_add_finish) begin
                        $display("psum info changed at negedge");
                        check_flag[2] <= 1'b1;
                        pe_psum_finish <= 1'b1;
                        psum_en <= ~psum_en;
                        psum_write_addr <= psum_tm_addr[cycle[2]];
                    end
                    $display("%0t ns cycle[0], [1], [2]: %d / %d / %d ", $time, cycle[0], cycle[1], cycle[2]);
                end
                delay_S3:
                begin
                    $display("%0t ns pe_array_controller's nxt state: delay_S3 ", $time);
                    //MAC_en = su_en[0];
                    pe_psum_finish = 1'b0;
                    check_flag[0] <= 1'b0; check_flag[1] <= 1'b0; check_flag[2] <= 1'b0;
                    if(actv_sel) begin actv_r_addr1 = {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 = actv_tm_addr[cycle[0]]; end
                    else begin actv_r_addr1 = actv_tm_addr[cycle[0]]; actv_r_addr2 = {ACTV_ADDR_BITWIDTH{1'bx}}; end
                    if(wgt_sel) begin wgt_r_addr1 = {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 = wgt_tm_addr[cycle[1]]; end
                    else begin wgt_r_addr1 = wgt_tm_addr[cycle[1]]; wgt_r_addr2 = {WGT_ADDR_BITWIDTH{1'bx}}; end
                    if(psum_en) begin psum_addr1 = psum_tm_addr[cycle[2]]; psum_addr2 = {PSUM_ADDR_BITWIDTH{1'bx}}; end
                    else begin psum_addr1 = {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 = psum_tm_addr[cycle[2]]; end
                    psum_write_addr = psum_tm_addr[cycle[2]];
                    $display("%0t ns cycle[0], [1], [2]: %d / %d / %d ", $time, cycle[0], cycle[1], cycle[2]);
                    $display("%0t ns actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr: %d / %d / %d / %d", $time, actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr);
                    $display("%0t ns actv_r_addr2, wgt_r_addr2, psum_addr2, psum_write_addr: %d / %d / %d / %d", $time, actv_r_addr2, wgt_r_addr2, psum_addr2, psum_write_addr);
                end
                S3:         // send the correct addr (signals set correctly on init_S3 state)
                begin
                    $display("%0t ns pe_array_controller's nxt state: S3 ", $time);
                    MAC_en <= su_en[0];
                    //pe_psum_finish <= 1'b0;
                    if(actv_sel) begin actv_r_addr1 <= {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 <= actv_tm_addr[cycle[0]]; end
                    else begin actv_r_addr1 <= actv_tm_addr[cycle[0]]; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}}; end
                    if(wgt_sel) begin wgt_r_addr1 <= {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 <= wgt_tm_addr[cycle[1]]; end
                    else begin wgt_r_addr1 <= wgt_tm_addr[cycle[1]]; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}}; end
                    if(psum_en) begin psum_addr1 <= psum_tm_addr[cycle[2]]; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; end
                    else begin psum_addr1 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 <= psum_tm_addr[cycle[2]]; end
                    psum_write_addr <= psum_tm_addr[cycle[2]];
                    $display("%0t ns cycle[0], [1], [2]: %d / %d / %d ", $time, cycle[0], cycle[1], cycle[2]);
                    $display("%0t ns actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr: %d / %d / %d / %d", $time, actv_r_addr1, wgt_r_addr1, psum_addr1, psum_write_addr);
                    $display("%0t ns actv_r_addr2, wgt_r_addr2, psum_addr2, psum_write_addr: %d / %d / %d / %d", $time, actv_r_addr2, wgt_r_addr2, psum_addr2, psum_write_addr);
                end
                FINISH:     // same as idle except conv_finish
                begin
                    $display("%0t ns pe_array_controller's nxt state: FINISH ", $time);
                    actv_rf1_need_data <= 1'b1; actv_rf2_need_data <= 1'b1; wgt_rf1_need_data <= 1'b1; wgt_rf2_need_data <= 1'b1;
                    pe_psum_finish <= 1'b0;
                    conv_finish <= 1'b1;
                    MAC_en <= {ROW*COL{1'b0}};
                    actv_sel <= 1'bx; actv_r_addr1 <= {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    wgt_sel <= 1'bx; wgt_r_addr1 <= {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}};
                    psum_en <= 1'bx; psum_addr1 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_write_addr <= {PSUM_ADDR_BITWIDTH{1'bx}};
                end
                default:    // same as idle
                begin
                    $display("%0t ns pe_array_controller's nxt state: default", $time);
                    actv_rf1_need_data <= 1'b1; actv_rf2_need_data <= 1'b1; wgt_rf1_need_data <= 1'b1; wgt_rf2_need_data <= 1'b1;
                    pe_psum_finish <= 1'b0;
                    conv_finish <= 1'b0;
                    MAC_en <= {ROW*COL{1'b0}};
                    actv_sel <= 1'bx; actv_r_addr1 <= {ACTV_ADDR_BITWIDTH{1'bx}}; actv_r_addr2 <= {ACTV_ADDR_BITWIDTH{1'bx}};
                    wgt_sel <= 1'bx; wgt_r_addr1 <= {WGT_ADDR_BITWIDTH{1'bx}}; wgt_r_addr2 <= {WGT_ADDR_BITWIDTH{1'bx}};
                    psum_en <= 1'bx; psum_addr1 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_addr2 <= {PSUM_ADDR_BITWIDTH{1'bx}}; psum_write_addr <= {PSUM_ADDR_BITWIDTH{1'bx}};
                end
            endcase
    end


    //at each state, update the cycle[0], cycle[1], cycle[2] and set flag reg at the end of the cycle on the negedge clk.
    always @(posedge clk) begin
            case(cur_state)
                IDLE:
                begin
                    cycle[0] <= {bits_for_cycle{1'b0}}; cycle[1] <= {bits_for_cycle{1'b0}}; cycle[2] <= {bits_for_cycle{1'b0}};
                    actv_flag <= 1'b0; wgt_flag <= 1'b0; psum_flag <= 1'b0;
                    turn_off <= 1'b0;
                end
                S1:
                    ;
                S2:
                begin
                    cycle[0] <= cycle[0]+1; cycle[1] <= cycle[1]+1; cycle[2] <= cycle[2]+1; 
                    if(cycle[0] == cycle_num[0])  actv_flag <= 1'b1;
                    if(cycle[1] == cycle_num[1])  wgt_flag <= 1'b1;
                    if(cycle[2] == cycle_num[2])  psum_flag <= 1'b1;
                end 
                WAIT:
                begin
                    cycle[0] <= cycle[0]; cycle[1] <= cycle[1]; cycle[2] <= cycle[2]; 

                end
                init_S3: //init_S3 is just for setting a new value
                begin
                    turn_off <= 1'b1;
                    
                    if(check_flag[0]) begin
                        $display("actv info changed at posedge");
                        actv_flag <= 1'b0; cycle[0] <= {bits_for_cycle{1'b0}};
                    end
                    if(check_flag[1]) begin
                        $display("wgt info changed at posedge");
                        wgt_flag <= 1'b0; cycle[1] <= {bits_for_cycle{1'b0}};
                    end

                    if(check_flag[2]) begin
                        $display("psum info changed at posedge");
                        psum_flag <= 1'b0; cycle[2] <= {bits_for_cycle{1'b0}};
                    end
                    $display("%0t ns cycle[0], [1], [2]: %d / %d / %d ", $time, cycle[0], cycle[1], cycle[2]);
                end
                delay_S3:
                begin
                    if(cycle[0] != {bits_for_cycle{1'b0}})
                        cycle[0] <= cycle[0]-2; 
                    if(cycle[1] != {bits_for_cycle{1'b0}})
                        cycle[1] <= cycle[1]-2; 
                    if(cycle[2] != {bits_for_cycle{1'b0}})
                        cycle[2] <= cycle[2]-2; 
                    turn_off <= 1'b0;
                end
                S3:
                begin
                    cycle[0] <= cycle[0]+1; cycle[1] <= cycle[1]+1; cycle[2] <= cycle[2]+1; 
                    if(cycle[0] == cycle_num[0])  actv_flag <= 1'b1;
                    if(cycle[1] == cycle_num[1])  wgt_flag <= 1'b1;
                    if(cycle[2] == cycle_num[2])  psum_flag <= 1'b1;
                end
                FINISH:
                    ;
            endcase
        end

endmodule