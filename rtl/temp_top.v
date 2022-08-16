/*========================================*\
    filename        : 
    description     : 
    up file         : 
    reversion       : 
        v1.0 : 
    author          : 张宸君
\*========================================*/

module temp_top #(parameter   MS_200 = 24'd10_000_000)(
    input                               clk             ,
    input                               rst_n           ,
    input           [ 2:0]              key_in          ,
    inout                               dq              ,

    output          [ 5:0]              SEL             ,
    output          [ 7:0]              DIG
);

// Parameter definition
    

// Signal definition
    wire            [15:0]              data            ;
    wire            [ 2:0]              press           ;
    wire            [ 1:0]              ratio           ;

// Module calls
    ds18b20 #(.MS_200(MS_200))      U_ds18b20(
        /*input                 */  .clk            (clk    ),
        /*input                 */  .rst_n          (rst_n  ),
        /*input           [ 2:0]*/  .press          (press  ),
        /*input                 */  .dq_in          (dq     ),
        /*output  reg           */  .dq_out         (dq     ),
        /*output  reg     [15:0]*/  .data_out       (data   ),
        /*output  reg     [ 1:0]*/  .ratio_out      (ratio  )
    );

    dig_demo                        U_dig_demo(
        /*input                 */  .clk            (clk    ), // 50MHz
        /*input                 */  .rst_n          (rst_n  ), // 复位信号
        /*input           [15:0]*/  .data_in        (data   ),
        /*input           [ 1:0]*/  .ratio          (ratio  ),
        /*output  reg     [ 5:0]*/  .SEL            (SEL    ), // SEL信号
        /*output  reg     [ 7:0]*/  .DIG            (DIG    )  // DIG信号
    );

    key_filter                      U_key_filter(
        /*input                 */  .clk            (clk    ),
        /*input                 */  .rst_n          (rst_n  ),
        /*input           [ 2:0]*/  .key_in         (key_in ),
        /*output  reg     [ 2:0]*/  .press          (press  )   
    );

// Logic description

    

endmodule