module sdram_sm #(
    parameter RSC_p = 2, //clk 133MHz
    parameter RP_p = 15, //nS
    parameter XSR_p = 0, //nS
    parameter REF_p = 0,
    parameter data_len_p = 0,
    parameter cas_laten_p = 2
)(
    input   logic   [0:0]   clk_i,
    input   logic   [0:0]   rst_i,
    input   logic   [0:0]   go_i,
    input   logic   [0:0]   delay_i,
    input   logic   [0:0]   rw_en_i,
    input   logic   [0:0]   read_valid_i,
    input   logic   [0:0]   write_ready_i,

    output  logic   [0:0]   ic_CS_o,
    output  logic   [0:0]   ic_RAS_o,
    output  logic   [0:0]   ic_CAS_o,
    output  logic   [0:0]   ic_WE_o,
    output  logic   [0:0]   ic_CKE_o,

    output  logic   [0:0]   read_ready_o,
    output  logic   [0:0]   write_valid_o
);

/*
    IDLE:
        out = 0111 (NOP)
        CKE = 1
        if (SR timeUp):
            out = 0001
            CKE = 0
            go to SR
        else if (go):
            out = 0010
            go to state PC
        else:
            out = 0111
            stay in IDLE
    
    PC:
        out = 0111 
        start t_RP delay
        if (delay done):
            if (SR timeUp):
                go to SR
                out = 0001
                CKE = 0
            else:
                go to SMR
                out = 0000
        else:
            stay in PC
    
    SMR: (Set Mode Register)
        out = 0111
        start t_RSC delay
        if (delay done):
            go to BA
            out = 0011
        else:
            stay in SMR
            out = 0111

    BA:
        out = 0111
        start t_RCD delay
        if (delay done):
            if (write and write is ready):
                go to WRITE
                out = 0101
            else if (read and read is valid):
                go to READ
                out = 0100
        else:
            stay in BA
            out = 0111
    
    READ:
        out = 0111
        if (read done & cas delay done):
            go to IDLE
            read ready = 1
            out = ???? (Might be DCs)
        else if (read done & cas delay not done):
            stay in READ
            begin cas delay
        else:
            stay in READ
    
    WRITE:
        out = 0111
        if (write done):
            write valid = 1
            go to IDLE
            out = ????
        else:
            stay in WRITE
    
    SR:
        out = 0001
        CKE = 0
        start t_REF relay
        if (REF delay done):
            begin t_XSR delay
            if (XSR delay done):
                go to IDLE
                CKE = 1
            else:
                stay in SR
                out = 0001
                CKE = 0
        else:
            stay in SR
            out = 0001
            CKE = 0


*/

endmodule