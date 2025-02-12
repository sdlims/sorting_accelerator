/*
Reminder! (IGNORE FOR NOW!!! MIGHT B FALSE)
    All ic outputs should be INVERTED when instantiated
    This logic is active HIGH not LOW (as IC Datasheet assumes)
*/

module memory_cntl //timescale in NS
    #(parameter t_RSC = 0,
        parameter t_RP = 15,
        parameter t_RAS = 0,
        parameter data_len = 0,
        parameter cas_laten = 2
    )(
        input   logic   [0:0]   clk_i,
        input   logic   [0:0]   rst_i,
        input   logic   [0:0]   go_i,
        input   logic   [0:0]   delay_i,
        input   logic   [0:0]   rw_en_i,
        input   logic   [0:0]   read_valid_i,
        input   logic   [0:0]   write_ready_i,

        // All outputs are the inverse of what they should be
        output  logic   [0:0]   ic_CS_o,
        output  logic   [0:0]   ic_RAS_o,
        output  logic   [0:0]   ic_CAS_o,
        output  logic   [0:0]   ic_WE_o,
        output  logic   [0:0]   ic_CKE_o,

        output  logic   [0:0]   t_RSC_delay_o,
        output  logic   [0:0]   t_RP_delay_o,
        output  logic   [0:0]   t_RAS_delay_o,
        output  logic   [0:0]   t_RCD_delay_o,

        output  logic   [0:0]   read_ready_o,
        output  logic   [0:0]   write_valid_o
    );


    logic [0:0] precharge_f, setmode_f, read_en_f, write_en_f;

    logic [2:0] state_d, state_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) state_q <= 3'd0;
        else state_q <= state_d;
    end

    logic [0:0] delay_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) delay_q <= 1'b0;
        else delay_q <= delay_i;
    end

    //Read and Write Counters
    logic [4:0] read_cnt_d, read_cnt_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) read_cnt_q <= 5'd0;
        else if (read_en_f) read_cnt_q <= read_cnt_d;
    end

    logic [4:0] write_cnt_d, write_cnt_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) write_cnt_q <= 5'd0;
        else if (write_en_f) write_cnt_q <= write_cnt_d;
    end

    logic [3:0] ic_l;
    logic [3:0] ic_delay_l;
    always_comb begin : memory_cntl_sm
        state_d = state_q;
        read_cnt_d = read_cnt_q;
        write_cnt_d = write_cnt_q;

        ic_l = {ic_CS_o, ic_RAS_o, ic_CAS_o, ic_WE_o};
        ic_delay_l = {t_RP_delay_o, t_RSC_delay_o, t_RAS_delay_o, t_RCD_delay_o};
        case(state_q)
            //INIT
            3'd0 : begin
                ic_l = 4'b0111
                if (go_i) begin
                    ic_l = 4'b0010;
                    ic_CKE_o = 1'b1;
                    state_d = 3'd1;
                end else begin
                    {ic_l, ic_CKE_o} = 5'b01111;
                    state_d = 3'd0;
                end
            end

            //PC
            3'd1 : begin
                ic_l = 4'b0111
                if (precharge_f & ~delay_q) begin
                    setmode_f = 1'b1;
                    precharge_f = 1'b0;

                    ic_l = 4'b0010;
                    ic_delay_l = 4'b1000;
                    state_d = 3'd1;
                end else if (setmode_f & ~delay_q) begin
                    ic_delay_l = 4'b0100;
                    setmode_f = 1'b0;

                    ic_l = 4'b0000; 
                    state_d = 3'd1;
                end else if (~precharge_f & ~setmode_f & ~delay_q) begin
                    ic_delay_l = 4'b0000;
                    precharge_f = 1'b1;

                    ic_l = 4'b0011;
                    state_d = 3'd2;
                end else begin
                    ic_l = 4'b0111;
                    state_d = 3'd1;
                end
            end

            //BA
            3'd2 : begin
                ic_l = 4'b0111
                ic_delay_l = 4'b0001;
                if (delay_q) begin
                    ic_l = 4'b0111;
                    state_d = 3'd2;
                end else if (~delay_q & ~rw_en_i & read_valid_i) begin
                    ic_l = 4'b0101;
                    ic_delay_l = 4'b0000;
                    state_d = 3'd3;
                end else if (~delay_q & rw_en_i & write_ready_i) begin
                    ic_l = 4'b0100;
                    ic_delay_l = 4'b0000;
                    state_d = 3'd4;
                end
            end 

            //READ
            3'd3 : begin
                ic_l = 4'b0111;
                if (read_cnt_q != data_len) begin // FIX COUNTER LOGIC, JOURNAL pg 
                    read_en_f = 1'b1;
                    read_cnt_d = read_cnt_q + 1;
                    state_d = 3'd3;
                end else begin
                    if (read_delay_cnt == cas_laten) begin
                        read_cnt_d = 5'd0;
                        read_en_f = 1'b0;
                        if (1) begin // Replace with actual SR Logic
                            state_d = 3'd5;
                        end else begin
                            state_d = 3'd1;
                            ic_l = 4'b0010;
                        end
                    end
                end
            end

            //WRITE
            3'd4 : begin
                ic_l = 4'b0111;
                if (write_cnt_q != data_len) begin // FIX COUNTER LOGIC, JOURNAL pg 
                    write_en_f = 1'b1;
                    write_cnt_d = write_cnt_q + 1;
                    state_d = 3'd4;
                end else begin
                    write_cnt_d = 5'd0;
                    write_en_f = 1'b0;
                    if (1) begin // Replace with actual SR Logic
                        ic_l = 4'b0001;
                        state_d = 3'd5;
                    end else begin
                        ic_l = 4'b0010;
                        state_d = 3'd1;
                    end
                end
            end

            //SR
            3'd5 : begin
                ;
            end

            default: begin
                state_n = 3'd0;
                {ic_l, ic_CKE_o} = 5'b01111;
                precharge_f = 1'b1;
                setmode_f = 1'b0;
                read_en_f = 1'b0;
                write_en_f = 1'b0;
                ic_delay_l = 4'b0000;
            end
        endcase
    end
endmodule

 // // Flags
    // logic [0:0] precharge_f = 1'b1, setmode_f = 1'b0, read_en_f = 1'b0, write_en_f = 1'b0;
    // logic [0:0] t_RP_del_f = 1'b0, t_RSC_del_f = 1'b0, t_XSR_del_f = 1'b0, t_REF_del_f = 1'b0;
    
    // // Delay Timer
    // logic [4:0] RP_t_l = 5'd0;
    // logic [0:0] RP_t_done_l;
    // always_ff @(posedge clk_i) begin : RP
    //     if (rst_i) begin
    //         RP_t_l <= 5'd0;
    //         RP_t_done_l <= 1'b0;
    //     end
    //     if (t_RP_del_f) begin
    //         RP_t_done_l <= 1'b1;
    //     end
    //     if (t_RP_del_f & RP_t_l != RP_p) begin
    //         RP_t_l <= RP_t_l + 1;
    //     end else if (!t_RP_del_f) begin
    //         RP_t_l <= 5'd0;
    //     end
    // end

    // logic [4:0] RSC_t_l = 5'd0;
    // logic [0:0] RSC_t_done_l = 1'b0;
    // always_ff @(posedge clk_i) begin : RSC
    //     if (rst_i) begin
    //         RSC_t_l <= 5'd0;
    //     end else if (t_RSC_del_f & RSC_t_l != RSC_p) begin
    //         RSC_t_l <= RSC_t_l + 1;
    //     end else if (!t_RSC_del_f) begin
    //         RSC_t_l <= 5'd0;
    //     end
    // end
    
    // logic [4:0] XSR_t_l = 5'd0;
    // logic [0:0] XSR_t_done_l = 1'b0;
    // always_ff @(posedge clk_i) begin : XSR
    //     if (rst_i) begin
    //         XSR_t_l <= 5'd0;
    //     end else if (t_XSR_del_f & XSR_t_l != XSR_p) begin
    //         XSR_t_l <= XSR_t_l + 1;
    //     end else if (!t_XSR_del_f) begin
    //         XSR_t_l <= 5'd0;
    //     end
    // end

    // logic [4:0] REF_t_l = 5'd0;
    // logic [0:0] REF_t_done_l = 1'b0;
    // always_ff @(posedge clk_i) begin : REF
    //     if (rst_i) begin
    //         REF_t_l <= 5'd0;
    //     end else if (t_REF_del_f & REF_t_l != REF_p) begin
    //         REF_t_l <= REF_t_l + 1;
    //     end else if (!t_REF_del_f) begin
    //         REF_t_l <= 5'd0;
    //     end
    // end

    // // D, Q FFs
    // logic [2:0] state_d, state_q;
    // always_ff @(posedge clk_i) begin
    //     if (rst_i) state_q <= 3'd0;
    //     else state_q <= state_d;
    // end

    // // logic [0:0] delay_d, delay_q;
    // // always_ff @(posedge clk_i) begin
    // //     if (rst_i) delay_q <= 1'b0;
    // //     else delay_q <= |{RP_t_done_l & (RP_t_l <= RP_p), 
    // //                     RSC_t_done_l & (RSC_t_l <= RSC_p), 
    // //                     XSR_t_done_l & (XSR_t_l <= XSR_p), 
    // //                     REF_t_done_l & (REF_t_l <= REF_p)};
    // // end

    // logic [3:0] ic_l = 4'b01111;
    // always_comb begin : memory_cntl_sm
    //     state_d = state_q;
        
    //     ic_l = {ic_CS_o, ic_RAS_o, ic_CAS_o, ic_WE_o};
    //     case(state_q)
    //         //INIT
    //         3'd0 : begin
    //             {ic_l, ic_CKE_o} = 5'b01111;
    //             if (go_i) begin
    //                 {ic_l, ic_CKE_o} = 5'b00101;
    //                 state_d = 3'd1;
    //             end else begin
    //                 {ic_l, ic_CKE_o} = 5'b01111;
    //                 state_d = 3'd0;
    //             end
    //         end

    //         //PC
    //         3'd1 : begin
    //             ic_l = 4'b0111;
    //             // Precharge
    //             if (precharge_f & ) begin
    //                 setmode_f = 1'b1;
    //                 precharge_f = 1'b0;
    //                 t_RP_del_f = 1'b1;

    //                 ic_l = 4'b0010;
    //                 state_d = 3'd1;
    //             // Set Mode
    //             end else if (setmode_f & ) begin
    //                 t_RP_del_f = 1'b0;
    //                 t_RSC_del_f = 1'b1;
    //                 setmode_f = 1'b0;

    //                 ic_l = 4'b0000; 
    //                 state_d = 3'd1;
    //             end else if (~precharge_f & ~setmode_f & ) begin
    //                 t_RSC_del_f = 1'b0;
    //                 precharge_f = 1'b1;

    //                 ic_l = 4'b0011;
    //                 state_d = 3'd2;
    //             end else begin
    //                 ic_l = 4'b0111;
    //                 state_d = 3'd1;
    //             end
    //         end

    //         //BA
    //         3'd2 : begin
    //             ;
    //         end
    //     endcase
    // end