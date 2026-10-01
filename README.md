# mincpu — 一个 8 位 CPU（Verilog）与它的汇编器

用 Verilog 从基本模块搭起来的一台 8 位 CPU，配一个用 Python 写的汇编器（把汇编翻译成 ROM 初始化代码）。
配套 Icarus Verilog + GTKWave，在 VS Code 里靠 `tasks.json` 一条命令完成"编译 → 仿真 → 看波形"。

## ⚠️ 先说清楚：这不是从零设计的架构

- 架构来源是游戏 **《图灵完备》（Turing Complete）** 里的 **LEG** 架构 —— 我在游戏里搭完那套 CPU 之后，用 Verilog 把它复刻了一遍。
- 指令集参考了 **B 站上一位作者写的该游戏专栏**（具体是哪一篇已记不清），在此基础上**自己改过好几轮**，所以现在这套指令编码**未必和原版一致**。
- 换句话说：**架构形态是学来的，Verilog 实现与这套指令编码是我自己写的**。仓库里保留三代版本正是这个修改过程的记录。

## 文件与代际

| 文件 | 时间 | 说明 |
|---|---|---|
| `test.v` | 01-23 | 最早的测试台（`include` 了第一版） |
| `all.v` | 01-24 | **第一代**：64 个寄存器（6 位地址）、16 位 PC、指令存储叫 `ProRAM`（64 KB） |
| `simple_all.v` | 01-25 | **第二代**：寄存器砍到 8 个（3 位地址）、PC 变 8 位、ROM/RAM/栈各 256 字节；**唯一能编译通过的一版** |
| `better_all.v` | 01-29 | **第三代**：重新设计编码（大类从 2 位扩到 3 位，把 push/pop 独立成模式），加模式译码器 `signal_generater` 与时钟门控；**未完成** |
| `tools/main.py` | 01-25 | **汇编器**：汇编文本 → Verilog ROM 初始化代码（`content[i] = 8'b...;`） |

`test.v` / `all.v` / `better_all.v` / `tools/main.py` 都保留**原样**，包括编译不过的地方 —— 它们是过程记录。

## 指令格式

一条指令 **4 字节定长**，`code0` 是操作码字节，`code1` / `code2` / `code3` 分别是两个源操作数与结果（兼作立即数）。

`code0` 分成三段：

| 位 | 含义 |
|---|---|
| `[7]` `[6]` | 立即数开关：为 1 则**第一个 / 第二个**操作数取立即数，否则读寄存器 |
| `[5:4]` | 指令大类：`00` 寄存器运算 · `01` 跳转 · `10` 内存控制 · `11` 停机 |
| `[3:0]` | 运算号（寄存器模式下）或条件号（跳转模式下）；内存模式下忽略 |

- **内存控制**靠大类最低位区分读/写；读时第二个操作数被忽略，第一个操作数解释为内存地址，结果写回寄存器；写时第一个操作数是值、第二个是地址。
- **停机**表示此后忽略所有指令；初始默认开机。

`code1`/`code2`/`code3` 都取低位作为寄存器编号（二代是 3 位，对应 8 个寄存器；一代是 6 位，对应 64 个）。

## call / return 是怎么实现的

这套 ISA 里**没有专门的 call 指令**，一行汇编就能看出设计意图：

```
'call':   '00010000',  # return null null null
'return': '00011000',  # call null null function_label
```

两条都属于**跳转大类**，靠低位 `0x0` / `0x8` 区分，然后配合栈：

```verilog
assign jump_place = pop_en ? pop_value : code3;   // pop 时跳回栈顶地址，否则跳到 code3
assign push_value = next + 8'h04;                 // push 时把"下一条指令"压栈
```

- `call null null func` → 压入下一条地址，跳到 `func`
- `return null null null` → 弹出返回地址并跳过去

代价是**一次调用要 2 条指令（8 字节）**，但换来的是更少的指令编码。

## 汇编器怎么用

```
python tools/main.py
```

它自带一段示例程序，直接打印可粘贴进 Verilog 的 ROM 初始化代码。规则：

- **两遍扫描**：第一遍收集所有 `label` 的地址绑定（每指令 +4），第二遍逐 token 解析 —— 所以标签可以**向前引用**。
- **token 解析优先级**：标签地址 > 指令/寄存器别名 > 十进制数字。
- 不足 4 个 token 用 `null` 补齐（即 `8'b0`）。
- 立即数模式体现在助记符后缀上：`add`（寄存器+寄存器）、`addi`（第一操作数立即数）、`addj`（第二操作数立即数）、`addij`（两个都是立即数）。

示例程序（编码器自带）演示了**循环 + 函数调用**：

```asm
call null null func_main
halt null null null

label func_main
addij 5 6 reg0          // reg0 = 11
call null null func_add
return null null null

label func_add
addj reg1 1 reg1        // reg1 += 1
addj reg2 2 reg2        // reg2 += 2
return null null null
```

## 实测状态（用 Icarus Verilog 实跑过）

| 文件 | 编译 | 仿真 | 说明 |
|---|---|---|---|
| **`simple_all.v`** | ✅ 通过 | ✅ **能跑，结果可复现** | 见下 |
| `all.v` | ❌ | — | `179` 行：`is_jump_mode = ...` 是裸赋值，Verilog 里必须写在 `always` 或 `assign` 里 |
| `better_all.v` | ❌ | — | `464` 行：`signal_generater generater(.code(code0), .isI1())` —— 那个未完成的模块 |
| `test.v` | ❌ | — | 第 3 行 `include "envir\\model\\mincpu\\all.v"` 找不到文件（路径与转义都不对） |

`simple_all.v` 的效果（它内嵌的测试程序正好是上面那段汇编的编码结果）：

```bash
iverilog -o simple_all.vvp simple_all.v
vvp simple_all.vvp
```

```
      10 | 0x00 | 0x00 | 0x00 | 0x00 | running     ← 初始化
      40 | 0x0c | 0x0b | 0x00 | 0x00 | running     ← reg0 = 11
     120 | 0x00 | 0x0b | 0x01 | 0x02 | running     ← 跳回循环入口
     280 | 0x04 | 0x0b | 0x02 | 0x04 | stopped     ← 停机，时钟随之停住
```

- 循环真的转了（PC 在 `0x00 → 0x08 → 0x0c → 0x14 → 0x18 → 0x1c → 0x00` 之间循环），寄存器随每一圈累加；
- 停机指令执行后时钟停住（`Clock` 的 `en` 接 `is_halt`），PC 冻在 `0x04`；
- **结果可复现**：把这次跑出的 `tb_CPU.vcd` 与 2026-01-25 那次留下的波形逐字节比较 —— **13228 字节完全相同，只有 12 个字节不同，且全部落在 `$date` 那一行的日期字符串里**。也就是说除了日期，仿真结果一个字节都不差。

> 那个历史波形在 `D:\code\Verilog\tb_CPU.vcd`（当年在上一层目录里跑的），不在本目录。

## 已知问题

- **两个条件跳转助记符对不上**：汇编器别名表里是 `jbqe` / `jsqe`，而 Verilog 的 `cond` 模块判的是 `jbeq` / `jseq` —— 这两条分支用汇编器编不出来（只能手写二进制）。两份文件各写各的，隔一天就不对号了。
- **`better_all.v` 换了编码格式，汇编器没跟着改**：三代把大类从 2 位扩成 3 位、并给 push/pop 独立的模式位，而 `tools/main.py` 至今生成的是**二代格式**的字节。
- **`test.v` 的 include 路径**：用了反斜杠相对路径，且注释里还写着"用 / 替代 \ 以兼容跨平台" —— 注释与代码不一致，换目录编译必炸。
- `tb_ALU` / `tb_register` / `tb_registers_64` 这些测试台的**源码不在这里**（只剩当年编译出的 `.vvp` 二进制）。

## 环境

- **仿真**：Icarus Verilog（`iverilog` / `vvp`）+ GTKWave（`gtkwave`）
- **编辑器**：VS Code，配套 `tasks.json` 提供三个任务：编译当前文件 / 运行仿真 / 打开波形
- 仓库内的 `.vvp` 与 `.vcd` 是当年的编译与仿真产物

## 说明

- 这是一个**学习性质**的复刻项目，不追求完整或工程可用性；保留了三代版本与所有编译不过的文件，因为它们记录的是"怎么一步步改的"。
