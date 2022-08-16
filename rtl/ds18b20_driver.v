/* ================================================ *\
        Filename    ﹕ ds18b20_driver.v
        Author      ﹕ Adolph
        Description ﹕ 本设计仅基于单个DS18B20在总线上工作的情况
        Called by   ﹕ 
Revision History    ﹕ 2022/8/10
                    Revision 1.0
            Email﹕ adolph1354238998@gamil.com
            Company﹕ AWCloud 
\* ================================================ */
module ds18b20_driver(
    input  					Clk		, //system clock 50MHz
    input  			 		Rst_n	, //reset, low valid
    
    input			[03:00]	key_flag, //[0]对应设置精度，[1]完成温度转换，[2]完成温度读取
    input					dq_in	, //三态门输入
    output	reg				dq_o	, //三态门输出    
    output	reg				dq_oe	, //三态门输出使能
    output	reg				sign	, //输出温度数据符号位 0：正，1：负       
    output	reg 	[15:00]	data_temp  //输出温度数据，输出格式 ：12345,123为温度整数部分，45为温度小数部分
);
//Parameter Declarations
    parameter 
        US_MAX       = 6'd50        ,//1us计数最大值
        MS_93        = 20'd93_750   ,//93.75MS 计数最大值
        MS_187       = 20'd187_500  ,//187.5MS 计数最大值
        MS_375       = 20'd375_000  ,//375MS 计数最大值
        MS_750       = 20'd750_000  ,//750MS 计数最大值
        INIT_TIME    = 20'd500      ,//复位/存在脉冲持续时间计数值
        RW_TIME_SLOT = 20'd70       ;//读写时隙持续时间计数值
    
    parameter	
        IDLE	    = 6'b00_0001, //空闲状态，不做任何操作
        INIT		= 6'b00_0010, //初始化
        SK_ROM		= 6'b00_0100, //跳过ROM指令
        ST_PRE		= 6'b00_1000, //设置温度数据 精度set precision
        ST_CNVT     = 6'b01_0000, //执行温度转换
        RD_TEMP     = 6'b10_0000; //执行读取温度数据
    
    parameter
        SEARCH_ROM  = 8'hF0, //主机必须识别总线上所有从设备的 ROM 编码
        READ_ROM    = 8'h33, //单个从机使用该指令，从机发送64bit ROM序列
        MATCH_ROM   = 8'h55, //后跟主机发送的64bit-ROM序列用以和唯一从机匹配
        SKIP_ROM    = 8'hCC, //可跳过rom序列直接驱动总线上所有设备完成温度转换，读取暂存器指令若跟其后，则从设备只能有一个
        ALARM_ROM   = 8'hEC, //只有置位了报警标志位的 DS18B20 才会响应这条指令
        DS_CONVERT  = 8'h44, //该指令发动一次温度转换
        DS_WRITE    = 8'h4E, //该指令允许主机对 DS18B20 暂存器写入最多 5 个数据
        DS_READ     = 8'hBE, //该指令允许主机读取暂存器中的内容,主机可以随时发布一个复位信号终止读取。
        DS_COPY     = 8'h48, //该指令将暂存器中的 TH， TL，配置寄存器和用户字节 3 和 4（字节 2,3,4,6,7）写入到 E2PROM
        DS_RECALL   = 8'hB8, //该指令从 E2PROM 中调用报警触发值（ TH 和 TL），配置寄存器和用户字节 4 和 5，并替换暂存器中字节 2,3,4,6 和 7 中对应的数据。
        DS_RD_POW   = 8'hB4; //主机发布本指令跟随一个读时隙以了解总线上是否有任何 DS18B20 在使用寄生电源供电

    parameter
        TEMP_H      = 8'h64,//有符号数以补码形式表示 +100-->0:110_0100
        TEMP_L      = 8'hec,//有符号数以补码形式表示 -20 -->1:110_1100
        SET_VALUE   = 8'h3f;//设置分辨率为10bit: 8'b0 01 11111

//Internal wire/reg declarations 
    reg		[05:00]	state_c, state_n; //
    reg			 	set_flag,cnvt_flag,rd_flag; //    
            
    //跳转条件定义
    wire            idle2init	;
    wire            init2skrom	;
    wire            init2idle	;
    wire            skrom2cnvt	;
    wire            skrom2rdtmp	;
    wire            skrom2set   ;
    wire            st_cnvt2idle;
    wire            st_prc2idle ;
    wire            rd_temp2idle;

    reg		[05:00]	cnt0	; // 基准计数器，计时1us	
    wire			add_cnt0; //Counter Enable
    wire			end_cnt0; //Counter Reset 
    
    reg		[19:00]	cnt1	; // us计数器
    wire			add_cnt1; //Counter Enable
    wire			end_cnt1; //Counter Reset 
    reg		[19:00] max_cnt1; //微秒计数器最大值

    reg		[03:00] bit_cnt ; //收发数据，位计数器
    reg		[03:00] byte_cnt; //收发字节计数器

    reg			 	plus_flag; //检测存在脉冲期间，低电平持续时间超过60us，即为高，回到 IDLE 状态时拉低
    reg		[07:00] cnt_plus ; //检测存在脉冲期间，低电平持续时间
    
    reg		[07:00] wr_data ; //发送数据暂存
    reg		[07:00] rd_data [01:00]; //接收温度数据暂存
    
    
    

//Module instantiations , self-build module

    
//Logic Description
    // 设置精度使能信号
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            set_flag  <= 1'b0;
        end  
        else if(st_prc2idle)begin  
            set_flag <= 1'b0;
        end  
        else if(key_flag[0])begin
            set_flag <= 1'b1;
        end
        else begin  
            set_flag <= set_flag;
        end  
    end //always end
    
    // 温度转化使能信号
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            cnvt_flag  <= 1'b0;
        end  
        else if(st_cnvt2idle)begin  
            cnvt_flag <= 1'b0;
        end  
        else if(key_flag[1])begin
            cnvt_flag <= 1'b1;
        end
        else begin  
            cnvt_flag <= cnvt_flag;
        end  
    end //always end
    
    // 读温度数据使能信号
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            rd_flag  <= 1'b0;
        end  
        else if(rd_temp2idle)begin  
            rd_flag <= 1'b0;
        end  
        else if(key_flag[2])begin
            rd_flag <= 1'b1;
        end
        else begin  
            rd_flag <= rd_flag;
        end  
    end //always end

    //第一段设置状态转移空间
    always @(posedge Clk or negedge Rst_n)begin
        if(!Rst_n)begin
            state_c <= IDLE;
        end
        else begin
            state_c <= state_n;
        end
    end //always end
    //第二段、组合逻辑定义状态转移
    always@(*)begin
        case(state_c)
            IDLE	:begin
                if(idle2init)begin
                    state_n = INIT;
                end
                else begin
                    state_n = IDLE; 
                end
            end
            INIT	:begin
                if(init2skrom)begin
                    state_n = SK_ROM;
                end
                else if(init2idle)begin
                    state_n = IDLE;
                end
                else begin
                    state_n = INIT; 
                end
            end
            SK_ROM	:begin
                if(skrom2set)begin
                    state_n = ST_PRE;
                end
                else if(skrom2cnvt)begin
                    state_n = ST_CNVT;
                end
                else if(skrom2rdtmp)begin
                    state_n = RD_TEMP;
                end
                else begin
                    state_n = SK_ROM; 
                end
            end
            ST_PRE	:begin
                if(st_prc2idle)begin
                    state_n = IDLE;
                end
                else begin
                    state_n = ST_PRE; 
                end
            end
            ST_CNVT :begin
                if(st_cnvt2idle)begin
                    state_n = IDLE;
                end
                else begin
                    state_n = ST_CNVT; 
                end
            end
            RD_TEMP :begin
                if(rd_temp2idle)begin
                    state_n = IDLE;
                end
                else begin
                    state_n = RD_TEMP; 
                end
            end
            default: begin
                state_n = IDLE;
            end
        endcase
    end //always end
            
    assign	idle2init	= state_c == IDLE	 && (set_flag || cnvt_flag || rd_flag)             ;//任意有一个标志信号都开启初始化
    assign	init2skrom	= state_c == INIT	 &&	bit_cnt == 4'd1 && end_cnt1 && plus_flag       ;//计满两轮500us，且成功接收存在脉冲
    assign	init2idle	= state_c == INIT	 &&	bit_cnt == 4'd1 && end_cnt1 && ~plus_flag      ;//计满两轮500us，未成功接收到复位脉冲
    assign	skrom2cnvt	= state_c == SK_ROM	 &&	bit_cnt == 4'd7 && end_cnt1 && cnvt_flag       ;//SKIP ROM 指令发完
    assign	skrom2rdtmp	= state_c == SK_ROM	 &&	bit_cnt == 4'd7 && end_cnt1 && rd_flag         ;//SKIP ROM 指令发完
    assign  skrom2set   = state_c == SK_ROM  && bit_cnt == 4'd7 && end_cnt1 && set_flag        ;//SKIP ROM 指令发完
    assign  st_cnvt2idle= state_c == ST_CNVT && bit_cnt == 4'd0 && byte_cnt == 4'd1 && end_cnt1;//写完转换指令后，等待最大转换时间结束
    assign  st_prc2idle = state_c == ST_PRE  && bit_cnt == 4'd7 && byte_cnt == 4'd3 && end_cnt1;//发送完3字节数据
    assign  rd_temp2idle= state_c == RD_TEMP && bit_cnt == 4'd7 && byte_cnt == 4'd2 && end_cnt1;//接收完2字节数据
            
    //第三段，定义状态机输出情况，可以时序逻辑，也可以组合逻辑
    // 基本计数1us计数器
    always @(posedge Clk or negedge Rst_n)begin  
        if(!Rst_n)begin  
            cnt0 <= 'd0; 
        end  
        else if(add_cnt0)begin // state_c不为IDLE状态则开始计数
            if(end_cnt0)begin  
                cnt0 <= 'd0; 
            end  
            else begin  
                cnt0 <= cnt0 + 1'b1; 
            end  
        end  
        else begin  
            cnt0 <= cnt0;  
        end  
    end //always end
    
    assign add_cnt0 = state_c != IDLE; 
    assign end_cnt0 = add_cnt0 && cnt0 >= US_MAX - 6'd1; 
    
    always @(posedge Clk or negedge Rst_n)begin  
        if(!Rst_n)begin  
            cnt1 <= 'd0; 
        end  
        else if(add_cnt1)begin  
            if(end_cnt1)begin  
                cnt1 <= 'd0; 
            end  
            else begin  
                cnt1 <= cnt1 + 1'b1; 
            end  
        end  
        else begin  
            cnt1 <= cnt1;  
        end  
    end //always end
    
    assign add_cnt1 = end_cnt0; 
    assign end_cnt1 = add_cnt1 && cnt1 >= max_cnt1; 

    always @(*)begin 
        if(!Rst_n)begin
            max_cnt1 = 'd0;
        end     
        else begin
            case(state_c)
                    INIT    : max_cnt1 = INIT_TIME;
                    SK_ROM  :max_cnt1 = RW_TIME_SLOT;
                    ST_CNVT :begin
                        if(byte_cnt == 4'd1)begin
                            max_cnt1 = MS_750;
                        end 
                        else begin
                            max_cnt1 = RW_TIME_SLOT; 
                        end
                    end
                    ST_PRE  :max_cnt1 = RW_TIME_SLOT;
                    RD_TEMP :max_cnt1 = RW_TIME_SLOT;
                default: ;
            endcase
        end
    end //always end

    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            bit_cnt <= 4'd0;        
        end  
        else if(state_c == IDLE)begin
            bit_cnt <= 4'd0;  
        end
        else if((state_c == INIT && bit_cnt == 4'd1)
                ||((state_c != IDLE && state_c != INIT) && bit_cnt == 4'd7))begin
            if(end_cnt1)begin        
                bit_cnt <= 4'd0;
            end            
            else begin
                bit_cnt <= bit_cnt + 4'd1;
            end            
        end
        else begin  
            bit_cnt <= bit_cnt;
        end  
    end //always end

    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            byte_cnt <= 4'd0;        
        end  
        else if(state_c == IDLE)begin  
            byte_cnt <= 4'd0;  
        end  
        else if(bit_cnt == 4'd7 && end_cnt1)begin
            byte_cnt <= byte_cnt + 4'd1;
        end
        else begin  
            byte_cnt <= byte_cnt;
        end  
    end //always end

    // cnt_plus
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            cnt_plus <= 8'd0;
        end  
        else if(state_c == IDLE)begin
            cnt_plus <= 8'd0; 
        end
        else if(state_c == INIT && ~dq_in && end_cnt0)begin  
            cnt_plus <= cnt_plus + 8'd1;
        end  
        else begin  
            cnt_plus <= cnt_plus;
        end  
    end //always end
    

// plus_flag
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            plus_flag <= 1'b0;
        end  
        else if(state_c == IDLE)begin  
            plus_flag <= 1'b0;
        end  
        else if(state_c == INIT && cnt_plus >= 8'd60)begin
            plus_flag <= 1'b1;
        end
        else begin  
            plus_flag <= plus_flag;
        end  
    end //always end

// 数据交互
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            dq_o    <= 1'b0;
            dq_oe   <= 1'b0;
            wr_data <= 8'd0;
            rd_data[0] <= 8'd0;
            rd_data[1] <= 8'd0;
        end 
        else begin  
            case(state_c)
                IDLE	:begin
                    dq_o    <= 1'b0;
                    dq_oe   <= 1'b0;
                    wr_data <= 8'd0; 
                end
                INIT	:begin
                    if(bit_cnt == 4'd1)begin //检测存在脉冲，释放总线控制权
                        dq_oe <= 1'b0;
                    end
                    else begin //发送复位脉冲，500us拉低
                        dq_oe <= 1'b1;
                        dq_o  <= 1'b0; 
                    end
                end
                SK_ROM	:begin
                    wr_data <= SKIP_ROM; //发送跳过ROM指令
                    // dq_o <= wr_data[bit_cnt];
                    if(wr_data[bit_cnt])begin //写1
                        if(cnt1 <= 2)begin
                            dq_oe <= 1'b1; //前2us拉低
                            dq_o  <= 1'b0; 
                        end
                        else begin
                            dq_oe <= 1'b0; //随后释放总线控制权
                            dq_o  <= 1'b0; 
                        end
                    end
                    else begin               //写0
                        dq_oe <= 1'b1;
                        dq_o  <= 1'b0; 
                    end
                end
                ST_PRE	:begin
                    case(byte_cnt)
                        0:wr_data <= DS_WRITE; //发送写入暂存器指令
                        1:wr_data <= TEMP_H  ; //温度报警值上限
                        2:wr_data <= TEMP_L  ; //温度报警值下限
                        3:wr_data <= SET_VALUE;//分辨率设置
                        default: wr_data <= 8'd0;
                    endcase
                    if(wr_data[bit_cnt])begin //写1
                        if(cnt1 <= 2)begin
                            dq_oe <= 1'b1; //前2us拉低
                            dq_o  <= 1'b0; 
                        end
                        else begin
                            dq_oe <= 1'b0; //随后释放总线控制权
                            dq_o  <= 1'b0; 
                        end
                    end
                    else begin               //写0
                        dq_oe <= 1'b1;
                        dq_o  <= 1'b0; 
                    end
                end
                ST_CNVT :begin
                    wr_data <= DS_CONVERT; //发送温度转换指令
                    // dq_o <= wr_data[bit_cnt];
                    if(byte_cnt == 4'd0)begin
                        if(wr_data[bit_cnt])begin //写1
                            if(cnt1 <= 2)begin
                                dq_oe <= 1'b1; //前2us拉低
                                dq_o  <= 1'b0; 
                            end
                            else begin
                                dq_oe <= 1'b0; //随后释放总线控制权
                                dq_o  <= 1'b0; 
                            end
                        end
                        else begin               //写0
                            dq_oe <= 1'b1;
                            dq_o  <= 1'b0; 
                        end
                    end
                    else begin
                        dq_oe <= 1'b0; 
                    end                    
                end
                RD_TEMP :begin
                    wr_data <= DS_READ; //发送读取暂存器指令
                    // dq_o <= wr_data[bit_cnt];
                    if(byte_cnt == 4'd0)begin //发送温度转换指令
                        if(wr_data[bit_cnt])begin //写1
                            if(cnt1 <= 2)begin
                                dq_oe <= 1'b1; //前2us拉低
                                dq_o  <= 1'b0; 
                            end
                            else begin
                                dq_oe <= 1'b0; //随后释放总线控制权
                                dq_o  <= 1'b0; 
                            end
                        end
                        else begin               //写0
                            dq_oe <= 1'b1;
                            dq_o  <= 1'b0; 
                        end
                    end
                    else if(byte_cnt == 4'd1)begin
                        if(cnt1 <= 1)begin //前2us,主机拉低，启动读时隙
                            dq_oe <= 1'b1;
                            dq_o  <= 1'b0;
                        end
                        else begin
                            dq_oe <= 1'b0;
                            if(cnt1 == 14 && end_cnt0)begin //数据写入
                                rd_data[0][bit_cnt] <= dq_in;
                            end 
                        end
                    end
                    else if(byte_cnt == 4'd2)begin
                        if(cnt1 <= 1)begin //前2us,主机拉低，启动读时隙
                            dq_oe <= 1'b1;
                            dq_o  <= 1'b0;
                        end
                        else begin
                            dq_oe <= 1'b0;
                            if(cnt1 == 14 && end_cnt0)begin //数据写入
                                rd_data[1][bit_cnt] <= dq_in;
                            end 
                        end
                    end
                    else begin
                        dq_oe <= 1'b0; 
                    end
                end
                default: begin
                    dq_o <= 1'b1;
                    dq_oe <= 1'b0; 
                end
            endcase
        end  
    end //always end
    
    // sign
    // data_temp
    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            sign <= 1'b0;
        end  
        else if(rd_temp2idle)begin  
            sign <= &rd_data[1][7:3]; //取出符号位
        end  
        else begin  
            sign <= sign;
        end  
    end //always end

    always @(posedge Clk or negedge Rst_n)begin 
        if(!Rst_n)begin  
            data_temp <= 16'd0;
        end  
        else if(rd_temp2idle)begin  
            if(rd_data[1][5])begin //取到负数
                data_temp <= ~({rd_data[1][2:0],rd_data[0]} - 1'b1) * 25; 
            end
            else begin
                data_temp <= {rd_data[1][2:0],rd_data[0]} * 25; 
            end
        end  
        else begin  
            data_temp <= data_temp;
        end  
    end //always end
    
endmodule 