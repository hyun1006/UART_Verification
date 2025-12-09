`timescale 1ns / 1ps

interface uart_interface;
    logic clk;
    logic rst;
    logic rx;
    logic tx;
endinterface


class transaction;
    randc logic [7:0] send_data;

    task display(string name_s);
        $display("%t, [%s] : data = %b", $time, name_s, send_data);
    endtask
endclass


class generator;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;

    event gen_next_event;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction

    task run(int count);
        trans = new();
        repeat (count) begin
            assert (trans.randomize())
            else $error("[GEN] trans.randomize() error !!! ");

            gen2drv_mbox.put(trans);
            //$display("          send start");

            trans.display("GEN");

            @(gen_next_event);
        end
    endtask
endclass


class driver;
    transaction trans;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) drv2scb_mbox;
    virtual uart_interface uart_if;

    parameter BIT_PERIOD = 104160;

    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_interface uart_if,
                 mailbox#(transaction) drv2scb_mbox);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_if      = uart_if;
        this.drv2scb_mbox = drv2scb_mbox;
    endfunction


    task reset();
        uart_if.clk = 0;
        uart_if.rst = 1;
        uart_if.rx  = 1;

        repeat (2) @(posedge uart_if.clk);
        uart_if.rst = 0;
        repeat (2) @(posedge uart_if.clk);
        $display("[DRV] reset done!");
    endtask

    task run();
        forever begin
            #1 gen2drv_mbox.get(trans);

            drv2scb_mbox.put(trans);
            trans.display("DRV");

            send(trans.send_data);
        end
    endtask

    task send(input [7:0] send_data);
        // start bit
        uart_if.rx = 1'b0;
        #(BIT_PERIOD);

        // data bit
        for (int k = 0; k < 8; k++) begin
            uart_if.rx = send_data[k];
            #(BIT_PERIOD);
        end

        // Stop Bit
        uart_if.rx = 1'b1;
        #(BIT_PERIOD);
    endtask
endclass



class monitor;
    transaction trans;
    virtual uart_interface uart_if;
    mailbox #(transaction) mon2scb_mbox;

    parameter BIT_PERIOD = 104160;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_interface uart_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_if      = uart_if;
    endfunction

    task run();
        forever begin
            @(negedge uart_if.tx);

            receive();
        end
    endtask

    task receive();
        trans = new;

        //$display("          receive start");
        #(BIT_PERIOD / 2);  // middle of start bit

        // start bit pass/fail
        if (!uart_if.tx) begin
            for (int j = 0; j < 8; j++) begin
                #(BIT_PERIOD);
                trans.send_data[j] = uart_if.tx;
            end

            trans.display("MON");

            // check stop bit
            #(BIT_PERIOD);
            if (uart_if.tx) begin
                mon2scb_mbox.put(trans);
            end
        end
    endtask
endclass


class scoreboard;
    transaction trans;
    transaction tr;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;
    event gen_next_event;

    int pass_count = 0, fail_count = 0, total_count = 0;

    function new(mailbox#(transaction) mon2scb_mbox, event gen_next_event,
                 mailbox#(transaction) drv2scb_mbox);
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
        this.drv2scb_mbox   = drv2scb_mbox;
    endfunction


    task run();
        forever begin
            drv2scb_mbox.get(tr);  // from driver
            mon2scb_mbox.get(trans);  //  from monitor
            trans.display("SCB");

            if (trans.send_data == tr.send_data) begin
                pass_count++;
                $display("[SCB] data matched! rx_data : %b == tx_data : %b",
                         tr.send_data, trans.send_data);
                $display(
                    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            end else begin
                fail_count++;
                $display(
                    "[SCB] data mis-matched... rx_data : %b != tx_data : %b",
                    tr.send_data, trans.send_data);
                $display(
                    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~");
            end

            total_count++;
            ->gen_next_event;
        end
    endtask
endclass


class environment;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;
    event gen_next_event;

    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    function new(virtual uart_interface uart_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        drv2scb_mbox = new();

        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, uart_if, drv2scb_mbox);
        mon = new(mon2scb_mbox, uart_if);
        scb = new(mon2scb_mbox, gen_next_event, drv2scb_mbox);
    endfunction

    task report();
        $display("===================================");
        $display("=========== test report ===========");
        $display("===================================");
        $display("==    Total Test : %d   ==", scb.total_count);
        $display("==    Pass Test  : %d   ==", scb.pass_count);
        $display("==    Fail Test  : %d   ==", scb.fail_count);
        $display("===================================");
        $display("==     Testbench is finished     ==");
        $display("===================================");
    endtask

    task run();
        drv.reset();
        fork
            gen.run(256);
            drv.run();
            mon.run();
            scb.run();
        join_any
        #10;
        report();
        $display("Finished");
        $stop;
    endtask
endclass


module tb_uart_top ();
    environment env;
    uart_interface uart_if ();

    logic b_tick;

    uart_top dut (
        .clk(uart_if.clk),
        .rst(uart_if.rst),
        .b_tick(b_tick),
        .rx(uart_if.rx),
        .tx(uart_if.tx)
    );

    baud_tick_gen U_BAUD_TICK (
        .clk     (uart_if.clk),
        .rst     (uart_if.rst),
        .o_b_tick(b_tick)
    );

    always #5 uart_if.clk = ~uart_if.clk;

    initial begin
        uart_if.clk = 0;

        env = new(uart_if);
        env.run();
    end
endmodule
