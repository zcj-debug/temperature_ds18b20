module key_filter #(parameter MS_20 = 20'd1000_000)(
    input                               clk         ,
    input                               rst_n       ,
    input           [ 2:0]              key_in      ,
  
    output  reg     [ 2:0]              press
);
// 全局变量定义

// 信号定义
    reg             [ 2:0]              key_0       ; // 按键信号当前时钟周期电平
    reg             [ 2:0]              key_1       ; // 按键信号下一个时钟周期电平

    wire            [ 2:0]              key_nedge   ; // 下降沿使能信号
    reg                                 add_flag    ; // 计数使能信号
    reg             [19:0]              delay_cnt   ; // 延时计数器

// 模块功能
    //打拍器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_0 <= 'b1;
            key_1 <= 'b1;
        end
        else begin
            key_0 <= key_in;
            key_1 <= key_0;
        end
    end

    // 检测下降沿
    assign key_nedge = ~key_0 & key_1;

    // 计数使能信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add_flag <= 'b0;
        end
        else if (key_nedge) begin
            add_flag <= 'b1;
        end
        else if (delay_cnt >= MS_20 - 1) begin
            add_flag <= 'b0;
        end
        else begin
            add_flag <= add_flag;
        end
    end

    // 计数20ms
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt <= 20'd0;
        end
        else if (add_flag) begin
            if (delay_cnt >= MS_20 - 1) begin
                delay_cnt <= 20'd0;
            end
            else begin
                delay_cnt <= delay_cnt + 1;
            end
        end
        else begin
            delay_cnt <= 20'd0;
        end
    end

    // 输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            press <= 'b0;
        end
        else if (delay_cnt >= MS_20 - 1) begin
            press <= ~key_in;
        end
        else begin
            press <= 'b0;
        end
    end

endmodule
