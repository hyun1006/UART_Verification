`timescale 1ns / 1ps

module uart_top (
    input  logic clk,
    input  logic rst,
    input  logic b_tick,
    input  logic rx,
    output logic tx
    //output tx_busy

    //input  tx_start,
    //input  [7:0] tx_data,
    //output [7:0] rx_data,
    //output rx_done
);

    logic w_rxdone_push, w_empty_start, w_txbusy_pop;
    logic w_tffull_rfpop, w_frempty_tfpush;
    logic [7:0] w_rxdata_pushdata, w_popdata_txdata, w_rfpopdata_tfpushdata;

    baud_tick_gen U_BAUD_TICK (
        .clk     (clk),
        .rst     (rst),
        .o_b_tick(b_tick)
    );

    uart_rx U_UART_RX (
        .clk    (clk),
        .rst    (rst),
        .rx     (rx),
        .b_tick (b_tick),
        .rx_done(w_rxdone_push),
        .rx_data(w_rxdata_pushdata)
    );

    fifo U_RX_FIFO (
        .clk  (clk),
        .rst  (rst),
        .wr   (w_rxdone_push),
        .rd   (~w_tffull_rfpop),
        .wdata(w_rxdata_pushdata),
        .rdata(w_rfpopdata_tfpushdata),
        .full (),
        .empty(w_frempty_tfpush)
    );

    fifo U_TX_FIFO (
        .clk  (clk),
        .rst  (rst),
        .wr   (~w_frempty_tfpush),
        .rd   (~w_txbusy_pop),
        .wdata(w_rfpopdata_tfpushdata),
        .rdata(w_popdata_txdata),
        .full (w_tffull_rfpop),
        .empty(w_empty_start)
    );

    uart_tx U_UART_TX (
        .clk     (clk),
        .rst     (rst),
        .tx_start(~w_empty_start),
        .tx_data (w_popdata_txdata),
        .b_tick  (b_tick),
        .tx_busy (w_txbusy_pop),
        .tx      (tx)
    );
endmodule


module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx_busy,
    output       tx
);

    localparam [1:0] IDLE = 2'b00, TX_START=2'b01, TX_DATA=2'b10, TX_STOP=2'b11;
    reg [1:0] state_reg, state_next;
    reg tx_busy_reg, tx_busy_next;
    reg tx_reg, tx_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx_busy = tx_busy_reg;
    assign tx = tx_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            tx_busy_reg    <= 1'b0;
            tx_reg         <= 1'b1;
            data_buf_reg   <= 8'h00;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg    <= 3'b000;
        end else begin
            state_reg      <= state_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end

    always @(*) begin
        state_next      = state_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                tx_next      = 1'b1;
                tx_busy_next = 1'b0;
                if (tx_start) begin
                    b_tick_cnt_next = 0; // modified
                    data_buf_next = tx_data;
                    state_next    = TX_START;
                end
            end

            TX_START: begin
                tx_next      = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next    = 0;
                        state_next      = TX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 0;
                            state_next = TX_STOP;
                        end else begin
                            b_tick_cnt_next = 0;
                            bit_cnt_next    = bit_cnt_reg + 1;
                            data_buf_next   = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            TX_STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule


module fifo (
    input              clk,
    input              rst,
    input  logic       wr,
    input  logic       rd,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    logic [2:0] waddr, raddr;
    logic wr_en;

    assign wr_en = wr & ~full;

    ram_reg_file U_RAM (
        .*,
        .wr(wr_en)
    );
    fifo_control_unit U_FIFO_CU (.*);
endmodule


module ram_reg_file #(
    parameter AWIDTH = 3
) (
    input                      clk,
    input  logic               wr,
    input  logic [AWIDTH -1:0] waddr,
    input  logic [AWIDTH -1:0] raddr,
    input  logic [        7:0] wdata,
    output logic [        7:0] rdata
);
    logic [7:0] ram[0:(2**AWIDTH) -1];  // ram[0:7]은 ram[8] 과 동일

    assign rdata = ram[raddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[waddr] <= wdata;
        end
    end
endmodule


module fifo_control_unit #(
    parameter AWIDTH = 3
) (
    input                      clk,
    input                      rst,
    input  logic               wr,
    input  logic               rd,
    output logic [AWIDTH -1:0] waddr,
    output logic [AWIDTH -1:0] raddr,
    output logic               full,
    output logic               empty
);

    logic [AWIDTH -1:0] raddr_reg, raddr_next;
    logic [AWIDTH -1:0] waddr_reg, waddr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign waddr = waddr_reg;
    assign raddr = raddr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    // state reg SL
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    // next CL
    always_comb begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({
            wr, rd
        })
            2'b01: begin  // pop
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1'b1;
                    end
                end
            end

            2'b10: begin  // push
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                    if (waddr_next == raddr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end

            2'b11: begin  // push, pop
                if (full_reg) begin
                    // pop
                    raddr_next = raddr_reg + 1;
                    full_next  = 1'b0;
                end else if (empty_reg) begin
                    // push
                    waddr_next = waddr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    raddr_next = raddr_reg + 1;
                    waddr_next = waddr_reg + 1;
                end
            end
        endcase
    end
endmodule
