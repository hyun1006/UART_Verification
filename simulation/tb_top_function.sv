`timescale 1ns / 1ps

module tb_uart_counter();

    // 1. 테스트벤치 신호 선언
    reg clk;
    reg rst;
    reg rx;

    wire tx;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    wire o_enable;
    wire o_clear;
    wire o_mode;

    wire b_tick;

    // 2. DUT 인스턴스화
    uart_top U_UART (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .o_enable(o_enable),
        .o_clear(o_clear),
        .o_mode(o_mode)
    );

    counter_top U_COUNTER (
        .clk(clk),
        .rst(rst),
        .mode(o_mode),
        .enable(o_enable),
        .clear(o_clear),
        .fnd_data(fnd_data),
        .fnd_com(fnd_com)
    );
    
    baud_tick_gen U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .o_b_tick(b_tick)
    );

    // 3. 클럭 생성 (100MHz)
    always #5 clk = ~clk;
    
    // ★★★ UART 문자 전송을 위한 '도우미' 태스크 (module 레벨에 정의) ★★★
    task send_char;
        input [7:0] char;
        parameter BIT_PERIOD = 104167; // 9600bps @ 100MHz clk
        begin
            // Start Bit
            rx = 1'b0;
            #(BIT_PERIOD);

            // Data Bits (LSB부터)
            for (int i = 0; i < 8; i = i + 1) begin
                rx = char[i];
                #(BIT_PERIOD);
            end

            // Stop Bit
            rx = 1'b1;
            #(BIT_PERIOD);
            
            // 다음 전송을 위해 Idle 상태 유지
            rx = 1'b1;
        end
    endtask

    // 4. 테스트 시나리오
    initial begin
        // --- 초기화 ---
        clk = 0;
        rst = 1;
        rx  = 1; // UART Idle 상태는 High
        #30;
        rst = 0;
        #20;
        $display("[%t] Reset is done. Starting test scenario...", $time);

        // --- 실제 테스트 시나리오 실행 ---
        
        #200_000;

        // 시나리오 1: 'r' 문자를 보내 카운터 동작 (enable 토글)
        $display("[%t] Sending 'r' to start/stop the counter.", $time);
        send_char("r"); // 태스크 호출
        #500_000;

        // 시나리오 2: 'c' 문자를 보내 카운터 초기화 (clear)
        $display("[%t] Sending 'c' to clear the counter.", $time);
        send_char("c"); // 태스크 호출
        #200_000;

        // 시나리오 3: 'm' 문자를 보내 카운터 모드 변경 (mode 토글)
        $display("[%t] Sending 'm' to change the mode.", $time);
        send_char("m"); // 태스크 호출
        #200_000;
        
        // 시나리오 4: 다시 'r' 문자를 보내 카운터 동작시키기
        $display("[%t] Sending 'r' again to start counter in new mode.", $time);
        send_char("r"); // 태스크 호출
        #500_000;

        $display("[%t] Test scenario finished.", $time);
        $stop;
    end
endmodule