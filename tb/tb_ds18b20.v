/*========================================*\
    filename        : tb_ds18b20.v
    description     : 仿真文件
    up file         : 
    reversion       : 
        v1.0 : 2022-8-10 19:34:07
    author          : 张某某
\*========================================*/

`timescale 1ns/1ns

module tb_ds18b20;

// Parameter definition
    parameter       CYC_CLK             = 20            ;

// Drive signal
    reg                                 tb_clk          ;
    reg                                 tb_rst_n        ;
    reg                                 tb_dq_in        ;
    reg             [ 2:0]              tb_press        ;

// Observation signal
    wire                                tb_dq_out       ;
    wire            [15:0]              tb_data_out     ;
    
// Module calls
    ds18b20   #(.MS_200(60_0000))      U_ds18b20(   
        /*input              */ .clk        (tb_clk     ),
        /*input              */ .rst_n      (tb_rst_n   ),
        /*input              */ .dq_in      (tb_dq_in   ),
        /*input        [ 2:0]*/ .press      (tb_press   ),
        /*output  reg        */ .dq_out     (tb_dq_out  ),
        /*output       [15:0]*/ .data_out   (tb_data_out)
    );

// System initialization
    initial begin
        tb_clk = 1'b1;
        tb_rst_n = 1'b0;
        #20 tb_rst_n = 1'b1;
    end
    always #10 tb_clk = ~tb_clk;

    initial begin
        tb_press = 3'b000;
        tb_dq_in = 1'bz;
        #(100 * CYC_CLK);

        #(100000);

        tb_press = 3'b100;
        #(CYC_CLK) tb_press = 3'b000;

        @(U_ds18b20.end_cnt_slot);

        // 从机发出存在脉冲
        #100 tb_dq_in = 1'b0;
        #(26_0000) tb_dq_in = 1'bz;

        @(U_ds18b20.idle2init);

        #(50_0000);

        // 从机发出存在脉冲
        #100 tb_dq_in = 1'b0;
        #(26_0000) tb_dq_in = 1'bz;

        @(U_ds18b20.skrom2convert);

        #(64_0000);

        // 从机回复1表示温度转换完成
        #(12000) tb_dq_in = 1'b1;
        #(30000) tb_dq_in = 1'bz;

        #(1200000);

        $stop;
    end
endmodule