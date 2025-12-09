`timescale 1ns / 1ps

module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    localparam [1:0] IDLE=2'b00,RX_START=2'b01, RX_DATA=2'b10,RX_STOP=2'b11;
    logic [1:0] state_reg, state_next;

    logic rx_done_reg, rx_done_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    assign rx_data = data_buf_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            rx_done_reg    <= 0;
            data_buf_reg   <= 0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
        end else begin
            state_reg      <= state_next;
            rx_done_reg    <= rx_done_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end


    always @(*) begin
        state_next      = state_reg;
        rx_done_next    = rx_done_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;

        case (state_reg)
            IDLE: begin
                rx_done_next = 1'b0;
                //if (b_tick) begin
                if (rx == 1'b0) begin
                    state_next = RX_START;
                end
                //end
            end

            RX_START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        b_tick_cnt_next  = 0;
                        bit_cnt_next     = 0;
                        data_buf_next[7] = rx;
                        state_next       = RX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            RX_DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;  // if(bit_cnt_reg == 6)
                        data_buf_next = data_buf_reg >> 1;  // 안에서 위로
                        data_buf_next[7] = rx;  // 끌어올림
                        if (bit_cnt_reg == 6) begin         // 7 -> 6 으로 횟수 변경
                            // bit_cnt_next = 0;
                            state_next = RX_STOP;
                        end else begin
                            // b_tick_cnt_next = 0;
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end

            RX_STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_done_next    = 1'b1;         // 추가하여 done 타이밍 문제 해결
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick_gen (
    input  logic clk,
    input  logic rst,
    output logic o_b_tick
);

    // 100_000_0000 / baud*16
    parameter BAUD = 9600;
    parameter BAUD_TICK_COUNT = 100_000_000 / BAUD / 16;

    logic [$clog2(BAUD_TICK_COUNT)-1:0] counter_reg;
    logic b_tick_reg;

    assign o_b_tick = b_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 1'b0;
        end else begin
            if (counter_reg == BAUD_TICK_COUNT - 1) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick_reg  <= 1'b0;
            end
        end
    end
endmodule


