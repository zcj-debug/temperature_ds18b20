/*========================================*\
    filename        : ds18b20.v
    description     : 与DS18B20温度传感器通信
    up file         : temp_top.v
    reversion       : 
        v1.0 : 2022-8-10 15:55:30
    author          : 张某某
\*========================================*/

module ds18b20 #(parameter MS_200 = 24'd10_000_000)(
    input                               clk             ,
    input                               rst_n           ,
    input           [ 2:0]              press           ,
    input                               dq_in           ,
    
    output  reg                         dq_out          ,
    output  reg     [15:0]              data_out        ,
    output  reg     [ 1:0]              ratio_out
);

// Parameter definition
    parameter   IDLE            =   6'b000_001  ,
                INIT            =   6'b000_010  ,
                SKROM           =   6'b000_100  ,
                SET             =   6'b001_000  ,
                CONVERT         =   6'b010_000  ,
                READ            =   6'b100_000  ;

    parameter   order_skrom     =   8'hcc       ,
                order_wrscr     =   8'h4e       ,
                order_convert   =   8'h44       ,
                order_rdscr     =   8'hbe       ,
                temp_hight      =   8'h28       , // 高温值
                temp_low        =   8'hf6       ; // 低温值

// Signal definition
    reg             [ 5:0]              state_c         ; // 现态
    reg             [ 5:0]              state_n         ; // 次态

    wire                                idle2init       ;
    wire                                init2idle       ;  
    wire                                init2skrom      ;
    wire                                skrom2set       ;
    wire                                skrom2convert   ;
    wire                                skrom2read      ;
    wire                                set2idle        ;
    wire                                convert2idle    ;
    wire                                read2idle       ;

    reg             [23:0]              cnt_400ms       ;
    wire                                add_cnt_400ms   ;
    wire                                end_cnt_400ms   ;

    reg             [14:0]              MAX_slot        ; // 最大时隙值
    reg             [ 2:0]              MAX_bit         ; // 最大bit值
    reg             [ 2:0]              MAX_byte        ; // 最大byte值

    reg             [14:0]              cnt_slot        ; // 时隙计数器
    wire                                add_cnt_slot    ;
    wire                                end_cnt_slot    ;

    reg             [ 2:0]              cnt_bit         ; // 比特计数器
    wire                                add_cnt_bit     ;
    wire                                end_cnt_bit     ;

    reg             [ 3:0]              cnt_byte        ; // 字节计数器
    wire                                add_cnt_byte    ;
    wire                                end_cnt_byte    ;

    reg             [ 7:0]              send_data       ; // 要发送的数据

    reg                                 flag_set        ; // 设置警报触发值使能信号
    reg                                 flag_convert    ; // 温度转换使能信号
    reg                                 flag_read       ; // 温度读取使能信号

    reg             [ 7:0]              ratio           ;

    reg                                 receive_en      ; // 获取dq_in数据使能信号
    reg             [15:0]              receive_data    ; // 接收到的数据

// Module calls
    

// Logic description
    /*************************************************
     第一段 状态转移
    *************************************************/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_c <= IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end

    /*************************************************
     第二段 状态转移规律
    *************************************************/
    always @(*) begin
        case (state_c)
            IDLE    :
                begin
                    if (idle2init) begin
                        state_n = INIT;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            INIT    :
                begin
                    if (init2idle) begin
                        state_n = IDLE;
                    end
                    else if (init2skrom) begin
                        state_n = SKROM;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            SKROM   :
                begin
                    if (skrom2set) begin
                        state_n = SET;
                    end
                    else if (skrom2convert) begin
                        state_n = CONVERT;
                    end
                    else if (skrom2read) begin
                        state_n = READ;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            SET     :
                begin
                    if (set2idle) begin
                        state_n = IDLE;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            CONVERT :
                begin
                    if (convert2idle) begin
                        state_n = IDLE;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            READ    :
                begin
                    if (read2idle) begin
                        state_n = IDLE;
                    end
                    else begin
                        state_n = state_c;
                    end
                end
            default : state_n = state_c;
        endcase
    end

    assign idle2init     = state_c == IDLE && (flag_convert || flag_set || flag_read);
    assign init2idle     = state_c == INIT && receive_en && end_cnt_byte && receive_data != 'd1;
    assign init2skrom    = state_c == INIT && receive_en && end_cnt_byte && receive_data == 'd1;
    assign skrom2set     = state_c == SKROM && flag_set && end_cnt_byte;
    assign skrom2convert = state_c == SKROM && flag_convert && end_cnt_byte;
    assign skrom2read    = state_c == SKROM && flag_read && end_cnt_byte;
    assign set2idle      = state_c == SET && end_cnt_byte;
    assign convert2idle  = state_c == CONVERT && receive_data == 'd1;
    assign read2idle     = state_c == READ && receive_en && end_cnt_byte;

    /*************************************************
     第三段 描述输出
    *************************************************/
    // 计数10_000_000个时钟周期
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_400ms <= 'd0;
        end
        else if (add_cnt_400ms) begin
            if (end_cnt_400ms) begin
                cnt_400ms <= 'd0;
            end
            else begin
                cnt_400ms <= cnt_400ms + 'd1;
            end
        end
        else begin
            cnt_400ms <= 'd0;
        end
    end
    assign add_cnt_400ms = 1'b1;
    assign end_cnt_400ms = add_cnt_400ms && cnt_400ms >= MS_200 - 'd1;

    // 设置警报触发值使能信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_set <= 1'b0;
        end
        else if (press) begin
            flag_set <= 1'b1;
        end
        else if (set2idle) begin
            flag_set <= 1'b0;
        end
        else begin
            flag_set <= flag_set;
        end
    end

    // 设置分辨率
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ratio <= 8'h7f;// 默认12分辨率
        end
        else begin
            case (press)
                3'b000 : ratio <= ratio;
                3'b100 : ratio <= 8'h1f;
                3'b010 : ratio <= 8'h3f;
                3'b001 : ratio <= 8'h5f;
                default: ratio <= 8'h7f;
            endcase
        end
    end

    // 分辨率输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ratio_out <= 'd0;
        end
        else if (state_c == READ && receive_en && end_cnt_byte) begin
            case (ratio)
                8'h1f : ratio_out <= 'd1; // 9分辨率
                8'h3f : ratio_out <= 'd2; // 10分辨率
                8'h5f : ratio_out <= 'd3; // 11分辨率
                default: ratio_out <= 'd0; // 0表示12分辨率
            endcase
        end
        else begin
            ratio_out <= ratio_out;
        end
    end

    // 温度转换使能信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_convert <= 'd0;
        end
        else if (end_cnt_400ms) begin
            flag_convert <= 'd1;
        end
        else if (convert2idle) begin
            flag_convert <= 'd0;
        end
        else begin
            flag_convert <= flag_convert;
        end
    end

    // 温度读取使能信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_read <= 'd0;
        end
        else if (convert2idle) begin
            flag_read <= 'd1;
        end
        else if (read2idle) begin
            flag_read <= 'd0;
        end
        else begin
            flag_read <= flag_read;
        end
    end

    // 接收数据使能信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            receive_en <= 'd0;
        end
        else if (state_c == INIT || state_c == CONVERT || state_c == READ) begin
            if (end_cnt_byte) begin
                receive_en <= 'd1;
            end
            else begin
                receive_en <= receive_en;
            end
        end
        else begin
            receive_en <= 'd0;
        end
    end

    // 最大时隙选择
    always @(*) begin
        case (state_c)
            IDLE :
                begin
                    MAX_slot = 15'd5; 
                    MAX_bit = 3'd0; 
                    MAX_byte = 2'd0;
                end
            INIT : 
                begin
                    MAX_slot = 15'd25000; // 计数500um
                    MAX_bit = 3'd0; // 1个bit
                    MAX_byte = 2'd0;
                end
            SKROM :
                begin
                    MAX_slot = 15'd4000; // 计数80um
                    MAX_bit = 3'd7; // 发送8个bit
                    MAX_byte = 2'd0; // 发送1个byte
                end
            SET :
                begin
                    MAX_slot = 15'd4000; // 计数80um
                    MAX_bit = 3'd7; // 发送8个比特
                    MAX_byte = 2'd3; // 发送4个byte
                end
            CONVERT :
                begin
                    MAX_slot = 15'd4000; // 计数80um
                    MAX_bit = 3'd7; // 发送8个比特
                    MAX_byte = 2'd0; // 发送1个byte
                end
            READ :
                begin
                    if (receive_en) begin
                        MAX_slot = 15'd4000; // 计数80um
                        MAX_bit = 3'd7; // 读取8个比特
                        MAX_byte = 2'd1; // 读取2个byte
                    end
                    else begin
                        MAX_slot = 15'd4000; // 计数80um
                        MAX_bit = 3'd7; // 发送8个比特
                        MAX_byte = 2'd0; // 发送4个byte
                    end
                    
                end
        endcase
    end

    // 时隙计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_slot <= 15'd0;
        end
        else if (add_cnt_slot) begin
            if (end_cnt_slot) begin
                cnt_slot <= 15'd0;
            end
            else begin
                cnt_slot <= cnt_slot + 15'd1;
            end
        end
        else begin
            cnt_slot <= 15'd0;
        end
    end
    assign add_cnt_slot = state_c != IDLE;
    assign end_cnt_slot = add_cnt_slot && cnt_slot >= MAX_slot - 15'd1;

    // bit计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_bit <= 3'd0;
        end
        else if (add_cnt_bit) begin
            if (end_cnt_bit) begin
                cnt_bit <= 3'd0;
            end
            else begin
                cnt_bit <= cnt_bit + 3'd1;
            end
        end
        else begin
            cnt_bit <= cnt_bit;
        end
    end
    assign add_cnt_bit = end_cnt_slot;
    assign end_cnt_bit = add_cnt_bit && cnt_bit >= MAX_bit;

    // 字节计数器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_byte <= 'd0;
        end
        else if (add_cnt_byte) begin
            if (end_cnt_byte) begin
                cnt_byte <= 'd0;
            end
            else begin
                cnt_byte <= cnt_byte + 'd1;
            end
        end
        else begin
            cnt_byte <= cnt_byte;
        end
    end
    assign add_cnt_byte = end_cnt_bit;
    assign end_cnt_byte = add_cnt_byte && cnt_byte >= MAX_byte;

    // 待发送的数据
    always @(*) begin
        case (state_c)
            SKROM : send_data = order_skrom;
            SET : 
                begin
                    case (cnt_byte)
                        0 : send_data = order_wrscr;
                        1 : send_data = temp_hight; // 高温报警
                        2 : send_data = temp_low; // 低温报警
                        3 : send_data = ratio; // 分辨率设置
                        default: send_data = 'd0;
                    endcase
                end
            CONVERT : send_data = order_convert;
            READ : send_data = order_rdscr;
            default: send_data = 'd0;
        endcase
    end

    // DQ_out 写时隙
    always @(*) begin
        case (state_c)
            IDLE : dq_out = 1'bz;
            INIT : 
                begin
                    if (receive_en) begin
                        dq_out = 1'bz;
                    end
                    else begin
                        dq_out = 1'b0;
                    end
                end
            SKROM, SET, CONVERT, READ: 
                begin
                    if (receive_en) begin
                        if (cnt_slot <= 150) begin
                            dq_out = 1'b0;
                        end
                        else begin
                            dq_out = 1'bz;
                        end
                    end
                    else begin // 写时隙
                        if (send_data[cnt_bit]) begin // 发送时隙1
                            if (cnt_slot <= 350) begin // 7um低电平
                                dq_out = 1'b0;
                            end
                            // else if (cnt_slot <= 750) begin // 7um-15um高阻态
                            //     dq_out = 1'bz;
                            // end
                            else begin
                                dq_out = 1'bz;
                            end
                        end
                        else begin // 发送时隙0
                            if (cnt_slot <= 3500) begin // 前70um低电平
                                dq_out = 1'b0;
                            end
                            else begin
                                dq_out = 1'bz; // 后10um高阻态
                            end
                        end 
                    end
                end
        endcase
    end

    // DQ_in 读时隙
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            receive_data <= 'd0;
        end
        else if (receive_en) begin
            if (state_c == INIT) begin
                if (dq_in == 1'b0) begin
                    receive_data = 'd1;
                end
                else begin
                    receive_data <= receive_data;
                end
            end
            else if (state_c == CONVERT) begin
                if (cnt_slot == 600) begin
                    receive_data[0] <= dq_in;
                end
                else begin
                    receive_data <= receive_data;
                end
            end
            else begin
                if (cnt_slot == 600) begin
                    receive_data[(cnt_byte << 3) + cnt_bit] <= dq_in;
                end
                else begin
                    receive_data <= receive_data;
                end
            end
        end
        else begin
            receive_data <= 'd0;
        end
    end

    // 数据输出
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 'd0;
        end
        else if (state_c == READ && receive_en && end_cnt_byte) begin
            data_out <= receive_data;
        end
        else begin
            data_out <= data_out;
        end
    end

endmodule