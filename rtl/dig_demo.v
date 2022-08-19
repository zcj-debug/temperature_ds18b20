/*========================================*\
  filename        : dig_demo.v
  description     : 滚动显示0-F
  up file         : 
  reversion       : 
      v1.0 : 2022-7-27 18:49:34
  author          : 张某某
\*========================================*/

module dig_demo #(parameter MS_1= 16'd50000)(
    input                                   clk                 ,   // 50MHz
    input                                   rst_n               ,   // 复位信号
    input               [15:0]              data_in             ,
    input               [ 1:0]              ratio               ,

    output      reg     [ 5:0]              SEL                 ,   // SEL信号
    output      reg     [ 7:0]              DIG                     // DIG信号
);

// 信号定义
    reg                 [15:0]              cnt_flicker         ;   // 计数1ms
    wire                                    SEL_change          ;   // cnt_flicker计满使能信号

    reg                 [ 3:0]              tmp_data            ;   // 当前DIG的值

    reg                                     point               ;

    wire                [ 6:0]              part_integer        ;   // 整数部分
    reg                 [13:0]              part_decimal        ;   // 小数部分

// 逻辑描述
    // 闪烁频率计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_flicker <= 'd0;
        end
        else if (SEL_change) begin
            cnt_flicker <= 'd0;
        end
        else begin
            cnt_flicker <= cnt_flicker + 'd1; 
        end
    end
    assign SEL_change = cnt_flicker >= MS_1 - 'd1 ? 1'b1 : 1'b0;

    // SEL信号输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            SEL <= 6'b011_111;
        end
        else if (SEL_change) begin
            SEL <= {SEL[4:0],SEL[5]};
        end
        else begin
            SEL <= SEL;
        end
    end

    //获取整数和小数部分
    assign part_integer = data_in[10:4];
    always @(*) begin
        case (ratio)
            2'd1 : part_decimal = data_in[3] ? 5 : 0;
            2'd2 : part_decimal = data_in[3] * 50 + data_in[2] * 25;
            2'd3 : part_decimal = data_in[3] * 500 + data_in[2] * 250 + data_in[1] * 125;
            default: part_decimal = data_in[3] * 5000 + data_in[2] * 2500 + data_in[1] * 1250 + data_in[0] * 625;
        endcase
    end

    // tmp_data当前SEL位选所对应的DIG十进制值
    always @(*) begin
        case (ratio)
            2'd0 : 
                begin 
                    case (SEL)
                        6'b111_110 : begin tmp_data = part_integer % 100 / 10;point = 1;end
                        6'b111_101 : begin tmp_data = part_integer % 100 % 10;point = 0;end
                        6'b111_011 : begin tmp_data = part_decimal / 1000;point = 1;end
                        6'b110_111 : begin tmp_data = part_decimal % 1000 / 100;point = 1;end
                        6'b101_111 : begin tmp_data = part_decimal % 1000 % 100 / 10;point = 1;end
                        6'b011_111 : begin tmp_data = part_decimal % 1000 % 100 % 10;point = 1;end
                    endcase
                end
            2'd1 : 
                begin 
                    case (SEL)
                        6'b111_110 : begin tmp_data = data_in[11] ? 11 : 10;point = 1;end
                        6'b111_101 : begin tmp_data = 10;point = 1;end
                        6'b111_011 : begin tmp_data = part_integer / 100 ? 1 : 10;point = 1;end
                        6'b110_111 : begin tmp_data = part_integer % 100 / 10;point = 1;end
                        6'b101_111 : begin tmp_data = part_integer % 100 % 10;point = 0;end
                        6'b011_111 : begin tmp_data = part_decimal;point = 1;end
                    endcase
                end
            2'd2 : 
                begin 
                    case (SEL)
                        6'b111_110 : begin tmp_data = data_in[11] ? 11 : 10;point = 1;end
                        6'b111_101 : begin tmp_data = part_integer / 100 ? 1 : 10;point = 1;end
                        6'b111_011 : begin tmp_data = part_integer % 100 / 10;point = 1;end
                        6'b110_111 : begin tmp_data = part_integer % 100 % 10;point = 0;end
                        6'b101_111 : begin tmp_data = part_decimal / 10;point = 1;end
                        6'b011_111 : begin tmp_data = part_decimal % 10;point = 1;end
                    endcase
                end
            2'd3 : 
                begin 
                    case (SEL)
                        6'b111_110 : begin tmp_data = data_in[11] ? 11 : 10;point = 1;end
                        6'b111_101 : begin tmp_data = part_integer % 100 / 10;point = 1;end
                        6'b111_011 : begin tmp_data = part_integer % 100 % 10;point = 0;end
                        6'b110_111 : begin tmp_data = part_decimal / 100;point = 1;end
                        6'b101_111 : begin tmp_data = part_decimal % 100 / 10;point = 1;end
                        6'b011_111 : begin tmp_data = part_decimal % 100 % 10;point = 1;end
                    endcase
                end
        endcase
    end

    // DIG输出各数字对应的二进制
    always @(*) begin
        case (tmp_data)
            4'd0 : DIG = {point, 7'b100_0000};
            4'd1 : DIG = {point, 7'b111_1001};
            4'd2 : DIG = {point, 7'b010_0100};
            4'd3 : DIG = {point, 7'b011_0000};
            4'd4 : DIG = {point, 7'b001_1001};
            4'd5 : DIG = {point, 7'b001_0010};
            4'd6 : DIG = {point, 7'b000_0010};
            4'd7 : DIG = {point, 7'b111_1000};
            4'd8 : DIG = {point, 7'b000_0000};
            4'd9 : DIG = {point, 7'b001_0000};
            4'd10: DIG = {point, 7'b111_1111};
            4'd11: DIG = {point, 7'b011_1111};
            default : DIG = 8'b1111_1111;
        endcase
    end

endmodule
