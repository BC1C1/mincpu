// 在原先的基础上开始加入流水线

// ---------- 以下是单周期版本的说明 ----------
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
// 内存控制时，仅写时立即数有效，读时忽略第二个操作数，第一个操作数解释为内存地址，结果地址解释为寄存器编号；写时忽略结果地址，第一个操作数为内存地址，第二个操作数为值。读写依靠指令类型的最后一位判断。
// 停机表示忽略后续所有指令，初始默认开机。

// ---------- 流水线说明 ----------
// 首先是完成拆分，原先1周期完成所有指令，现在

// ---------- 基本组件（数据选择器等） ----------
module Clock(
    input en,
    output reg clk
);
initial begin
    clk = 0;
end
always #10 clk = en ? ~clk : 0;
endmodule

module decode_3to8(
    input en,
    input [2:0] location,
    output reg [7:0] signal
);
always @(*) begin
    signal = 8'h00;
    signal[location] = en ? 1'b1 : 1'b0;
end
endmodule

module decode_2to4(
    input en,
    input [1:0] location,
    output reg [3:0] signal
);
always @(*) begin
    signal = 8'h00;
    signal[location] = en ? 1'b1 : 1'b0;
end
endmodule

// ---------- 寄存器相关 ----------
module register(
    input clk,
    input re1,
    input re2,
    input we,
    input[7:0] data,
    output [7:0] output1,
    output [7:0] output2,
    output [7:0] test_output
);
reg [7:0] content;
initial begin
    content = 8'h00;
end
always @(posedge clk) begin
    if (we) begin
        content <= data;
    end
end
assign output1 = re1 ? content : 8'bz;
assign output2 = re2 ? content : 8'bz;
assign test_output = content;
endmodule

// ---------- ALU、cond ----------
module ALU(
    input [7:0] code,    
    input [7:0] op1,     
    input [7:0] op2,     
    output reg [7:0] result  
);
reg[15:0] temp; 
always @(*) begin
    result = op1;
    
    case (code[3:0])  // 4位运算码（0-15），覆盖16种运算
        4'h0: result = op1 + op2;                                           // add
        4'h1: result = op1 - op2;                                           // sub
        4'h2: result = op1 & op2;                                           // and
        4'h3: result = op1 | op2;                                           // or
        4'h4: result = ~op1;                                                // not
        4'h5: result = op1 ^ op2;                                           // xor
        4'h6: result = op1 << op2[2:0];                                     // sll
        4'h7: result = op1 >> op2[2:0];                                     // srl
        4'h8: begin temp = op1 * op2; result = temp[7:0]; end               // mul
        4'h9: result = (op2 != 8'h00) ? (op1 / op2) : 8'h00;                // div
        4'hA: result = (op2 != 8'h00) ? (op1 % op2) : 8'h00;                // mod
        4'hB: result = (op1 == op2) ? 8'h00 : (op1 > op2) ? 8'h01 : 8'h02;  // cmp
        4'hC: result = op2;                                                 // mov
        4'hD: result = {op2[7:4], op1[7:4]};                                // swap
        4'hE: result = op1 + 8'h01;                                         // inc
        4'hF: result = op1;                                                 // nop
    endcase
end

endmodule

module better_ALU(
    input[15:0] deal_modes,
    input [7:0] op1,     
    input [7:0] op2,  
    output reg[7:0] result
);
reg[15:0] temp; 
always @(*) begin
    result = op1;
    
    case (deal_modes)  // 4位运算码（0-15），覆盖16种运算
        16'h0: result = op1 + op2;                                           // add
        16'h1: result = op1 - op2;                                           // sub
        16'h2: result = op1 & op2;                                           // and
        16'h3: result = op1 | op2;                                           // or
        16'h4: result = ~op1;                                                // not
        16'h5: result = op1 ^ op2;                                           // xor
        16'h6: result = op1 << op2[2:0];                                     // sll
        16'h7: result = op1 >> op2[2:0];                                     // srl
        16'h8: begin temp = op1 * op2; result = temp[7:0]; end               // mul
        16'h9: result = (op2 != 8'h00) ? (op1 / op2) : 8'h00;                // div
        16'hA: result = (op2 != 8'h00) ? (op1 % op2) : 8'h00;                // mod
        16'hB: result = (op1 == op2) ? 8'h00 : (op1 > op2) ? 8'h01 : 8'h02;  // cmp
        16'hC: result = op2;                                                 // mov
        16'hD: result = {op2[7:4], op1[7:4]};                                // swap
        16'hE: result = op1 + 8'h01;                                         // inc
        16'hF: result = op1;                                                 // nop
    endcase
end
endmodule

module cond(
    input [7:0] code,
    input [7:0] op1,
    input [7:0] op2,
    output reg is_jump
);
always @(*) begin
    is_jump = 1'b0;
    case (code[2:0])
        3'h0: is_jump = 1'b1;                       // jalw
        3'h1: is_jump = op1 > op2 ? 1'b1 : 1'b0;    // jbig
        3'h2: is_jump = op1 < op2 ? 1'b1 : 1'b0;    // jsma
        3'h3: is_jump = op1 >= op2 ? 1'b1 : 1'b0;   // jbeq
        3'h4: is_jump = op1 <= op2 ? 1'b1 : 1'b0;   // jseq
        3'h5: is_jump = op1 == op2 ? 1'b1 : 1'b0;   // jequ
        3'h6: is_jump = op1 != op2 ? 1'b1 : 1'b0;   // jneq
        3'h7: is_jump = 1'b0;                       // jnev
        default: is_jump = 1'b0;
    endcase
end
endmodule

// ---------- PC+程序计数器 ----------
module PC(
    input clk,
    input is_jump,
    input[7:0] jump_place,
    output[7:0] next
);
reg [7:0] content;
initial begin
    content = 8'h00;
end
always @(posedge clk) begin
    if (is_jump) content <= jump_place;
    else content <= content + 4;
end
assign next = content;
endmodule

module ProRAM(
    input[7:0] next,
    output[7:0] code0,
    output[7:0] code1,
    output[7:0] code2,
    output[7:0] code3
);
reg[7:0] content[255:0];
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) begin
        content[i] = 8'h00;
    end
    // 这里可以写测试指令
    // content[0] = xxxxxxxx;
    // 1. reg0 = 10;
    content[0] = 8'b00010000;
    content[1] = 8'b00000000;
    content[2] = 8'b00000000;
    content[3] = 8'b00001000;
    content[4] = 8'b00110000;
    content[5] = 8'b00000000;
    content[6] = 8'b00000000;
    content[7] = 8'b00000000;
    content[8] = 8'b11000000;
    content[9] = 8'b00000101;
    content[10] = 8'b00000110;
    content[11] = 8'b00000000;
    content[12] = 8'b00010000;
    content[13] = 8'b00000000;
    content[14] = 8'b00000000;
    content[15] = 8'b00010100;
    content[16] = 8'b00011000;
    content[17] = 8'b00000000;
    content[18] = 8'b00000000;
    content[19] = 8'b00000000;
    content[20] = 8'b01000000;
    content[21] = 8'b00000001;
    content[22] = 8'b00000001;
    content[23] = 8'b00000001;
    content[24] = 8'b01000000;
    content[25] = 8'b00000010;
    content[26] = 8'b00000010;
    content[27] = 8'b00000010;
    content[28] = 8'b00011000;
    content[29] = 8'b00000000;
    content[30] = 8'b00000000;
    content[31] = 8'b00000000;
end
assign code0 = content[next];
assign code1 = content[next + 1];
assign code2 = content[next + 2];
assign code3 = content[next + 3];
endmodule

// ---------- RAM+PCstack ----------
module RAM(
    input clk,
    input we,
    input re,
    input[7:0] location,
    input[7:0] data,
    output reg[7:0] value
);
reg[7:0] content[255:0];
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) begin
        content[i] = 8'h00;
    end
    value = 8'h00;
end
always @(*) begin
    if (re) value = content[location];
    else value = 8'h00;
end
always @(posedge clk) begin
    if (we) content[location] <= data;
end
endmodule

module PCstack(
    input clk,
    input push_en,
    input pop_en,
    input [7:0] push_value,
    output reg [7:0] pop_value
);
reg [7:0] content[255:0];
reg [7:0] ptr;
integer i;
initial begin
    for (i = 0; i < 256; i = i + 1) begin
        content[i] = 8'h00;
    end
    ptr = 8'h00;
    pop_value = 8'h00;
end
always @(posedge clk) begin
    if (push_en) begin
        content[ptr] = push_value;
        ptr <= ptr + 1;
    end else if (pop_en) begin
        pop_value <= content[ptr - 1];
        ptr <= ptr - 1;
    end
end
endmodule

// ---------- cpu ----------
module CPU(
    output [7:0] reg0_out,
    output [7:0] reg1_out,
    output [7:0] reg2_out,
    output [7:0] reg3_out,
    output [7:0] reg4_out,
    output [7:0] reg5_out,
    output [7:0] next_out
);
// clock
reg is_halt;
initial begin is_halt = 1'b1; end
always @(*) begin
    is_halt = code0 == 8'b00110000 ? 1'b0 : 1'b1;
end
wire clk;
Clock clock(.en(is_halt), .clk(clk));

// PC + ProRAM(ROM)
wire [7:0] jump_place;
wire [7:0] next;
wire is_jump;
PC pc(.clk(clk), .is_jump(is_jump), .jump_place(jump_place), .next(next));
wire [7:0] code0;
wire [7:0] code1;
wire [7:0] code2;
wire [7:0] code3;
ProRAM proRAM(.next(next), .code0(code0), .code1(code1), .code2(code2), .code3(code3));
// registers(6)
    // 解码器部分
wire [2:0] location_re1;
wire [7:0] signal_re1;
decode_3to8 decoder_for_re1(.en(1'b1), .location(location_re1), .signal(signal_re1));
wire [2:0] location_re2;
wire [7:0] signal_re2;
decode_3to8 decoder_for_re2(.en(1'b1), .location(location_re2), .signal(signal_re2));
wire [2:0] location_we;
wire [7:0] signal_we;
reg write_enable;
always @(*) begin 
    write_enable = (code0[5:4] == 2'b00 ? 1'b1 : 1'b0) ||           // 寄存器控制时写寄存器允许
                   (code0[5:3] == 3'b100 ? 1'b1 : 1'b0)             // 内存控制读取时写寄存器允许
                   ; 
end
decode_3to8 decoder_for_we(.en(write_enable), .location(location_we), .signal(signal_we));
    // 三条总线
wire [7:0] data; // write
wire [7:0] output1; // output1
wire [7:0] output2; // output2
    // 寄存器
register reg0(.clk(clk), .re1(signal_re1[0]), .re2(signal_re2[0]), .we(signal_we[0]), .data(data), .output1(output1), .output2(output2), .test_output(reg0_out));
register reg1(.clk(clk), .re1(signal_re1[1]), .re2(signal_re2[1]), .we(signal_we[1]), .data(data), .output1(output1), .output2(output2), .test_output(reg1_out));
register reg2(.clk(clk), .re1(signal_re1[2]), .re2(signal_re2[2]), .we(signal_we[2]), .data(data), .output1(output1), .output2(output2), .test_output(reg2_out));
register reg3(.clk(clk), .re1(signal_re1[3]), .re2(signal_re2[3]), .we(signal_we[3]), .data(data), .output1(output1), .output2(output2), .test_output(reg3_out));
register reg4(.clk(clk), .re1(signal_re1[4]), .re2(signal_re2[4]), .we(signal_we[4]), .data(data), .output1(output1), .output2(output2), .test_output(reg4_out));
register reg5(.clk(clk), .re1(signal_re1[5]), .re2(signal_re2[5]), .we(signal_we[5]), .data(data), .output1(output1), .output2(output2), .test_output(reg5_out));
// ALU
wire [7:0] op1_alu;
wire [7:0] op2_alu;
wire [7:0] result;
ALU alu(.code(code0), .op1(op1_alu), .op2(op2_alu), .result(result));
// cond
wire [7:0] op1_cond;
wire [7:0] op2_cond;
wire is_jump_result;
cond u_cond(.code(code0), .op1(op1_cond), .op2(op2_cond), .is_jump(is_jump_result));
// RAM
reg we_ram;
reg re_ram;
wire [7:0] ram_location;
wire [7:0] ram_data;
wire [7:0] ram_output;
always @(*) begin
    we_ram = code0[5:3] == 3'b101;
    re_ram = code0[5:3] == 3'b100;
end
RAM ram(.clk(clk), .we(we_ram), .re(re_ram), .location(ram_location), .data(ram_data), .value(ram_output));
// PCStack
reg push_en;
reg pop_en;
wire [7:0] push_value;
wire [7:0] pop_value;
always @(*) begin
    push_en = code0[5:3] == 3'b010;
    pop_en = code0[5:3] == 3'b011;
end
PCstack stack(.clk(clk), .push_en(push_en), .pop_en(pop_en), .push_value(push_value), .pop_value(pop_value));
// 连接
// 函数跳转
    // push
    assign push_value = next + 8'h04;
// 寄存器控制：从proRAM里读取到四个code，按照规则code0的末尾控制操作类型，这个由ALU模块自己处理，code1、code2、code3的末尾分别是re1，re2，we的控制信号，于是：
assign location_re1 = code1[2:0];
assign location_re2 = code2[2:0];
assign location_we = code3[2:0];
// 跳转控制信号连接
assign is_jump = is_jump_result & (code0[5:4] == 2'b01 ? 1'b1 : 1'b0);
// 具体数据通路：寄存器读到output1和output2总线，随后分别输入ALU, 由于内部无数据，加入立即数模式，由code0的顶两位控制. cond的控制也一样
assign op1_alu = code0[7] ? code1 : output1;
assign op2_alu = code0[6] ? code2 : output2;
assign op1_cond = code0[7] ? code1 : output1;
assign op2_cond = code0[6] ? code2 : output2;
// 最后输出回写的总线, 加入内存控制
wire is_from_ram;
assign is_from_ram = (code0[5:3] == 3'b100);
assign data = is_from_ram ? ram_output : result;
// 跳转地址输入
assign jump_place = pop_en ? pop_value : code3;
// 内存地址
assign ram_location = op1_alu;
    // 写入
    assign ram_data = output2;
// PC 监视
assign next_out = next;
endmodule

module signal_generater(
    input [7:0] code,
    output reg isI1,
    output reg isI2,
    output reg register_mode,
    output reg jump_mode,
    output reg RAM_mode,
    output reg halt_mode,
    output reg [16:0] deal_modes
);
integer i;
always @(*) begin
    isI1 = code[7];
    isI2 = code[6];
    register_mode = code[5:4] == 2'b00;
    jump_mode = code[5:4] == 2'b01;
    RAM_mode = code[5:4] == 2'b10;
    halt_mode = code[5:4] == 2'b11;
    deal_modes = 16'b0000_0000_0000_0000; 
    case (code[3:0])
        4'h0: deal_modes[0]  = 1'b1;  // add
        4'h1: deal_modes[1]  = 1'b1;  // sub
        4'h2: deal_modes[2]  = 1'b1;  // and
        4'h3: deal_modes[3]  = 1'b1;  // or
        4'h4: deal_modes[4]  = 1'b1;  // not
        4'h5: deal_modes[5]  = 1'b1;  // xor
        4'h6: deal_modes[6]  = 1'b1;  // sll
        4'h7: deal_modes[7]  = 1'b1;  // srl
        4'h8: deal_modes[8]  = 1'b1;  // mul
        4'h9: deal_modes[9]  = 1'b1;  // div
        4'hA: deal_modes[10] = 1'b1;  // mod
        4'hB: deal_modes[11] = 1'b1;  // cmp
        4'hC: deal_modes[12] = 1'b1;  // mov
        4'hD: deal_modes[13] = 1'b1;  // swap
        4'hE: deal_modes[14] = 1'b1;  // inc
        4'hF: deal_modes[15] = 1'b1;  // nop
    endcase
end
endmodule

module better_cpu(
    
);
// 取指、译码
wire [7:0] jump_place;
wire [7:0] next;
wire is_jump;
PC pc(.clk(clk), .is_jump(is_jump), .jump_place(jump_place), .next(next));
wire [7:0] code0;
wire [7:0] code1;
wire [7:0] code2;
wire [7:0] code3;
ProRAM proRAM(.next(next), .code0(code0), .code1(code1), .code2(code2), .code3(code3));
reg isI1;
reg isI2;

signal_generater generater(.code(code0), .isI1())
endmodule

// ---------- 测试相关 ---------- 
module tb_CPU;

// 1. 输出端口（对接CPU的调试输出）
wire [7:0] reg0_out, reg1_out, reg2_out, reg3_out, reg4_out, reg5_out;
wire [7:0] next_out;

// 2. 实例化你的CPU模块
CPU u_CPU(
    .reg0_out(reg0_out),
    .reg1_out(reg1_out),
    .reg2_out(reg2_out),
    .reg3_out(reg3_out),
    .reg4_out(reg4_out),
    .reg5_out(reg5_out),
    .next_out(next_out)
);

// 3. 仿真控制：生成波形+打印日志+结束仿真
initial begin
    // 生成VCD波形文件（可用GTKWave查看）
    $dumpfile("tb_CPU.vcd");
    $dumpvars(0, tb_CPU);
    
    // 打印表头（删除RAM列）
    $display("===== CPU仿真测试 ======");
    $display("时间(ns) | PC   | reg0 | reg1 | reg2 | 状态");
    $display("------------------------|------|------|------|------------");
    
    // 延长仿真时间：repeat(50) → 50*10ns=500ns，足够覆盖call/return完整流程
    repeat(50) begin
        #10;
        $display("%8d | 0x%02X | 0x%02X | 0x%02X | 0x%02X | %s",
                 $time, next_out, reg0_out, reg1_out, reg2_out,
                 u_CPU.is_halt ? "running" : "stopped");
    end
    
    // 强制结束仿真
    $finish;
end

endmodule