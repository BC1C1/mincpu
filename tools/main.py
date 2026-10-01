# 恢复指令别名表（你提供的完整版本）
assembly_alias_to_code = {
    # code0：运算码（bit7-6=立即数模式，bit2-0=运算类型）
    'add': '00000000',  # 寄存器+寄存器 加法
    'addi': '10000000',  # 立即数+寄存器 加法
    'addj': '01000000',  # 寄存器+立即数 加法
    'addij': '11000000',  # 立即数+立即数 加法
    'sub': '00000001',  # 减法
    'subj': '01000001',
    'and': '00000010',  # 按位与
    'or': '00000011',  # 按位或
    'not': '00000100',  # 按位非
    'call': '00010000',  # return null null null
    'return': '00011000',  # call null null function_label
    'jbig': '00010001',
    'jsma': '00010010',
    'jsmaj': '01010010',
    'jbqe': '00010011',
    'jsqe': '00010100',
    'jequ': '00010101',
    'jneq': '00010110',
    'jneqj': '01010110',
    'jnev': '00010111',
    'read': '00100000',
    'write': '00101000',
    'halt': '00110000',
    # code1/code2/code3：寄存器地址（仅bit2-0有效）
    'reg0': '00000000',
    'reg1': '00000001',
    'reg2': '00000010',
    'reg3': '00000011',
    'reg4': '00000100',
    'reg5': '00000101',
    'null': '00000000',  # 被忽略用这个
}


def dec_to_8bit_bin(dec_num: int) -> str:
    """将十进制数转换为8位二进制字符串（补前导0）"""
    if not 0 <= dec_num <= 255:
        raise ValueError(f"十进制数{dec_num}超出8位范围（0~255）")
    return bin(dec_num)[2:].zfill(8)


def transform(assembly_text: str):
    """
    最终版规则（预扫描label + 指令别名解析）：
    1. 预扫描所有行 → 收集所有label的绑定关系
    2. 二次扫描 → 解析指令（别名/数字/标签）→ 生成Verilog代码
    3. 指令按4字节编码，cnt +=4 对齐
    """
    label_map = {}  # 标签名: 绑定的地址（cnt值）
    temp_cnt = 0  # 预扫描用计数器
    lines = [line.strip() for line in assembly_text.splitlines()]

    # ====================== 第一步：预扫描 → 收集所有label ======================
    for line in lines:
        if not line or line.startswith('//'):
            continue
        line_content = line.split('//')[0].strip()
        tokens = line_content.split()
        if not tokens:
            continue

        # 处理label并绑定地址
        i = 0
        has_label = False
        while i < len(tokens):
            if tokens[i] == 'label':
                has_label = True
                if i + 1 >= len(tokens):
                    raise ValueError(f"label后未跟标签名：{line}")
                label_name = tokens[i + 1]
                if label_name in label_map:
                    raise ValueError(f"重复定义标签：{label_name}")
                label_map[label_name] = temp_cnt  # 标签绑定当前cnt（下一条指令地址）
                i += 2
            else:
                i += 1

        # 非纯label行 → cnt +=4
        if not has_label or (has_label and len(tokens) > 2):
            temp_cnt += 4

    # ====================== 第二步：处理指令 → 生成Verilog代码 ======================
    cnt = 0
    result = ""
    for line in lines:
        if not line or line.startswith('//'):
            continue
        line_content = line.split('//')[0].strip()
        tokens = line_content.split()
        if not tokens:
            continue

        # 过滤label，保留指令token
        new_tokens = []
        i = 0
        while i < len(tokens):
            if tokens[i] == 'label':
                i += 2
            else:
                new_tokens.append(tokens[i])
                i += 1

        # 处理指令（核心：解析别名/数字/标签）
        if new_tokens:
            # 补全4个token
            while len(new_tokens) < 4:
                new_tokens.append('null')  # 用null补（自动映射为00000000）
            inst_tokens = new_tokens[:4]

            # 逐个解析token
            for idx, token in enumerate(inst_tokens):
                # 优先级：标签 > 指令别名 > 十进制数字
                if token in label_map:
                    # 1. 标签 → 转绑定地址的二进制
                    bin_code = dec_to_8bit_bin(label_map[token])
                elif token in assembly_alias_to_code:
                    # 2. 指令/寄存器别名 → 直接取映射值
                    bin_code = assembly_alias_to_code[token]
                elif token.isdigit():
                    # 3. 十进制数字 → 转8位二进制
                    bin_code = dec_to_8bit_bin(int(token))
                else:
                    # 4. 未知token → 报错
                    raise ValueError(f"未知指令/数字/标签：{token}（行：{line}）")

                # 生成Verilog代码行
                result += f"    content[{cnt + idx}] = 8'b{bin_code};\n"

            # 计数器+4
            cnt += 4

    return result


# 测试示例
if __name__ == "__main__":
    assembly_code = """
call null null func_main
halt null null null 

label func_main
addij 5 6 reg0
call null null func_add
return null null null

label func_add
addj reg1 1 reg1
addj reg2 2 reg2
return null null null
    """
    try:
        verilog_code = transform(assembly_code)
        print("===== 生成的Verilog ROM初始化代码 =====")
        print(verilog_code)
    except ValueError as e:
        print(f"错误：{e}")