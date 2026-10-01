// 1. 包含文件：用/替代\（跨平台兼容），相对路径从当前文件出发
`include "envir\\model\\mincpu\\all.v"

module tb_CPU;
    // 1. 定义测试信号（新增PC_value输出）
    wire [7:0] reg0_out;
    wire [7:0] reg1_out;
    wire [7:0] reg2_out;
    wire [15:0] PC_value; // 新增：监控PC输出的地址

    // 2. 实例化CPU（注意：CPU模块需要新增PC_value输出端口）
    CPU u_cpu(
        .reg0_out(reg0_out),
        .reg1_out(reg1_out),
        .reg2_out(reg2_out),
        .PC_value(PC_value) // 新增：导出PC的地址值
    );

    // 3. 仿真控制：逐拍打印+全周期监控
    initial begin
        // 打印表头（更清晰）
        $display("------------------------ 执行日志 ------------------------");
        $display("时间(ns) | PC地址 | reg0 | reg1 | reg2 | 状态");
        $display("---------------------------------------------------------");
        
        // 逐拍打印（每10ns打印一次，匹配时钟周期）
        repeat(20) begin // 运行20个时钟周期（200ns）
            #10;
            $display("%8d | 0x%04h | 0x%02h | 0x%02h | 0x%02h | %s",
                     $time, PC_value, reg0_out, reg1_out, reg2_out,
                     (PC_value == 16'h0000) ? "执行指令1" :
                     (PC_value == 16'h0004) ? "执行指令2" :
                     (PC_value == 16'h0008) ? "执行指令3" :
                     (PC_value == 16'h000C) ? "执行停机指令" : "空指令");
        end

        // 4. 结束仿真
        #10;
        $display("---------------------------------------------------------");
        $display("仿真结束！");
        $finish;
    end
endmodule