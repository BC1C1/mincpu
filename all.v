
// 总体设计为8位，固定宽指令4*8bit为一条指令。
// xxxxxxxx xxxxxxxx xxxxxxxx xxxxxxxx
// 指令类型  操作数1  操作数2   结果地址  （操作数1,2也为地址，可从寄存器或从内存中读取）
// 指令详细解释
// 指令类型：8位。分成2、2、4三个部分
// 第一部分是立即数开关，第一个为1表示第一个操作数为立即数而不是地址，第二个为1说明第二个为立即数而不是地址。在立即数无效的场景忽略
// 第二部分是具体指令类型，00表示寄存器控制，01表示跳转，10表示内存控制，11表示停机
// 第三部分是操作类型，在第二部分为00时，后四位解释为对两个操作数的运算方式，在第二部分为01时，后四位解释成对两个操作数的比较方式，在10时忽略。
// 寄存器控制时，立即数有效，运算结果由ALU模块得出，地址解释为寄存器编号。
// 跳转时，立即数有效，比较结果由cond模块得出，结果地址解释为跳转地址。
// 内存控制时，仅写时立即数有效，读时忽略第二个操作数，第一个操作数解释为内存地址，结果地址解释为寄存器编号；写时忽略结果地址，第一个操作数为值，第二个操作数为内存地址。读写依靠指令类型的最后一位判断，0为读，1为写。
// 停机表示忽略后续所有指令，初始默认开机。

// ---------- 下面是寄存器组相关 ----------
// 基础寄存器
module register(
    input clk,
    input [7:0] data,
    input we,
    input re1,
    input re2,
    output reg [7:0] output1,
    output reg [7:0] output2
);
reg [7:0] content;
initial begin
    content = 8'b00000000; 
    output1 = 8'b00000000;
    output2 = 8'b00000000;
end
always @(posedge clk) begin
    if (we) content <= data;
end
always @(*) begin
    output1 = re1 ? content : 8'h00;
    output2 = re2 ? content : 8'h00;
end
endmodule
// 6到64解码器
module decode_6to64(
    input [5:0] location,
    output reg [63:0] signal
);
always @(*) begin
    signal = 64'd0;
    signal[location] = 1'b1;
end
endmodule
// 寄存器组
module registers_64(
    input clk,
    input [7:0] data,
    input [5:0] write_location,
    input [5:0] read_location1,
    input [5:0] read_location2,
    output reg [7:0] output1,
    output reg [7:0] output2,
    output reg [7:0] reg0_out,
    output reg [7:0] reg1_out,
    output reg [7:0] reg2_out
);
reg [7:0] regs [63:0];
integer i;

initial begin
    for(i=0; i<64; i=i+1) regs[i] = 8'h00;
    reg0_out = 8'h00;
    reg1_out = 8'h00;
    reg2_out = 8'h00;
end

always @(posedge clk) begin
    regs[write_location] <= data; 
    reg0_out <= regs[0];
    reg1_out <= regs[1];
    reg2_out <= regs[2];
end

always @(*) begin
    output1 = regs[read_location1];
    output2 = regs[read_location2];
end
endmodule

// ---------- 下面是ALU相关 ----------
// 4到16解码器
module decode_4to16(
    input [3:0] location,
    output reg [15:0] signal
); 
always @(*) begin
    signal = 16'b0000000000000000;
    signal[location] = 1'b1;
end
endmodule
// 1.加法器
module adder(
    input [7:0] op1,
    input [7:0] op2,
    output reg [7:0] sum
);
always @(*) begin
    sum = op1 + op2;
end
endmodule
// 2.减法器
module suber(
    input [7:0] op1,
    input [7:0] op2,
    output reg [7:0] sum // 这个名称别管它
);
reg [7:0] temp;
always @(*) begin
    temp = (~op2) + 8'b00000001;
    sum = op1 + temp;
end
endmodule
// 3.按位与
module and_8bit(
    input [7:0] op1,
    input [7:0] op2,
    output reg [7:0] sum
);
always @(*) begin
    sum = op1 & op2;
end
endmodule
// 4.按位或
module or_8bit(
    input [7:0] op1,
    input [7:0] op2,
    output reg [7:0] sum
);
always @(*) begin
    sum = op1 | op2;
end
endmodule
// 5.按位非
module not_8bit(
    input [7:0] op,
    output reg [7:0] sum
);
always @(*) begin
    sum = ~op;
end
endmodule
// ALU
module ALU(
    input[7:0] code,
    input[7:0] op1,
    input[7:0] op2,
    output [7:0] result
);
wire[15:0] decode_en;
decode_4to16 decoder(.location(code[3:0]), .signal(decode_en));
wire[7:0] caculate_result[15:0];
adder u_adder(.op1(op1), .op2(op2), .sum(caculate_result[0]));
suber u_suber(.op1(op1), .op2(op2), .sum(caculate_result[1]));
and_8bit u_ander(.op1(op1), .op2(op2), .sum(caculate_result[2]));
or_8bit u_orer(.op1(op1), .op2(op2), .sum(caculate_result[3]));
not_8bit u_noter(.op(op1), .sum(caculate_result[4]));
assign result = decode_en[0] ? caculate_result[0] :
                decode_en[1] ? caculate_result[1] :
                decode_en[2] ? caculate_result[2] :
                decode_en[3] ? caculate_result[3] :
                decode_en[4] ? caculate_result[4] :
                op1;
endmodule

// ---------- 条件跳转模块 ----------
module cond(
    input[7:0] code,
    input[7:0] op1,
    input[7:0] op2,
    output is_jump
);
reg is_jump_mode;
is_jump_mode = code[5:4] == 2'd01 ? 1'd1 : 1'd0;

endmodule

// ---------- 整体cpu ----------
// 时钟
module Clock(
    input en,
    output reg clk
);
initial begin
    clk = 0;
end
always #10 clk = en ? ~clk : 0;
endmodule
// 程序计数器
module PC(
    input clk,
    input is_jump,
    input [15:0] jump_place, // 由跳转检查元件输出
    output reg [15:0] place  
);
initial begin
    place = 16'b0000000000000000; // 初始地址=0
end
always @(posedge clk) begin
    if (is_jump) begin
        place <= jump_place;
    end else begin
        place <= place + 16'b0000000000000100; // +4
    end
end
endmodule
// ProRAM
module ProRAM(
    input[15:0] place,
    output[7:0] value0, 
    output[7:0] value1,  
    output[7:0] value2,  
    output[7:0] value3 
);
integer i; 
reg[7:0] content[65535:0];
initial begin
    for(i = 0; i < 65536; i = i + 1) begin
        content[i] = 8'b00000000; 
    end
    // 这里写入测试指令
    // (1) reg0 = reg0 + 2
    // 01000000(addj) 00000000(reg0) 00000010(1) 00000000(reg0)
    // (2) reg1 = reg0
    // 01000000(addj) 00000000(reg0) 00000000(0) 00000001(reg1)
    // (3) reg2 = reg1 - 1
    // 01000001(subj) 00000001(reg1) 00000001(1) 00000010(reg2)
    // (4) 停机
    // 00110000(stop) 00000000       00000000    00000000
    content[0]  = 8'b01000000;
    content[1]  = 8'b00000000;
    content[2]  = 8'b00000011;
    content[3]  = 8'b00000000;

    content[4]  = 8'b11000000;
    content[5]  = 8'b00000001;
    content[6]  = 8'b00000011;
    content[7]  = 8'b00000001;

    content[8]  = 8'b01000001;
    content[9]  = 8'b00000001;
    content[10] = 8'b00000001;
    content[11] = 8'b00000010;

    content[12] = 8'b00110000;
    content[13] = 8'b00000000;
    content[14] = 8'b00000000;
    content[15] = 8'b00000000;

end
assign value0 = content[place];    
assign value1 = content[place + 1];   
assign value2 = content[place + 2];   
assign value3 = content[place + 3];   
endmodule
// 二选一数据选择器
module selector_2to1_8bit(
    input[7:0] data1,
    input[7:0] data2,
    input sel,
    output reg[7:0] value
);
always @(*) begin
    value = sel ? data2 : data1; // 默认第一个，加高电平第二个
end
endmodule
// cpu
module CPU(
    output [7:0] reg0_out, 
    output [7:0] reg1_out,
    output [7:0] reg2_out,
    output [15:0] PC_value
);
// 整体时钟
wire clk;
Clock clock(.en(1'b1), .clk(clk));
// 1. PC + 程序
wire is_jump;
wire[15:0] jump_place;
wire[15:0] place; // PC输出地址
PC pc(.clk(clk), .is_jump(1'b0), .jump_place(jump_place), .place(place)); // 暂时不用跳转功能
assign PC_value = place;
wire[7:0] code0;
wire[7:0] code1;
wire[7:0] code2;
wire[7:0] code3;
ProRAM proRAM(.place(place), .value0(code0), .value1(code1), .value2(code2), .value3(code3));
// 2. 寄存器模块
wire[7:0] data;
wire[7:0] output1;
wire[7:0] output2;
registers_64 registers( .clk(clk), 
                        .data(data), 
                        .write_location(code3[5:0]), 
                        .read_location1(code1[5:0]), 
                        .read_location2(code2[5:0]), 
                        .output1(output1), 
                        .output2(output2),
                        .reg0_out(reg0_out),
                        .reg1_out(reg1_out),
                        .reg2_out(reg2_out)
                    );
// 3. ALU模块
wire[7:0] result;
wire[7:0] op1;
wire[7:0] op2;
selector_2to1_8bit for_op1(.data1(output1), .data2(code1), .sel(code0[7]), .value(op1)); // 这两个数据选择器为了立即数
selector_2to1_8bit for_op2(.data1(output2), .data2(code2), .sel(code0[6]), .value(op2));
ALU u_ALU(.code(code0), .op1(op1), .op2(op2), .result(result));
// 4. 停机检查
reg is_halt;
initial begin
    is_halt = 1'b0; 
end
always @(*) begin
    if ((code0 >> 4) & 3'b11 == 3'b11) begin // 提取bit5-4
        is_halt = 1'b1;
    end else begin
        is_halt = 1'b0;
    end
end
// 5. 连接各模块(缺失的连线)
reg [7:0] data_mask;
always @(*) begin
    case (code3[5:0]) // code3是结果地址（寄存器编号）
        6'd0: data_mask = result; // 写reg0时，data=result
        6'd1: data_mask = result; // 写reg1时，data=result
        6'd2: data_mask = result; // 写reg2时，data=result
        default: data_mask = 8'h00; // 其他寄存器，data=0（不修改）
    endcase
end

// 改写回逻辑：停机时data=0，否则=data_mask
assign data = is_halt ? 8'h00 : data_mask;
// 第一版测试：仅有寄存器之间的操作，就是从寄存器中读取并直接输入ALU运算并写回的操作
endmodule