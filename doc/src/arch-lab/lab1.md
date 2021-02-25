# 实验 1：五级流水线 MIPS CPU

> 先修内容：《深入学习计算机系统》Chapter 4: Pipelined Y86 CPU



## 1.1 MIPS 微体系结构

五级流水线，属于体系结构的范畴。不同指令集的 CPU ，都可以有五级流水线的实现。

指令集是微体系结构的一部分，规范了指令编码等信息。

MIPS 属于精简指令集（Reduced Instruction Set Computing， RISC）。我们需要实现的 MIPS ，部分基本信息如下：

* 每条指令长度为4Byte（32bit）
* 32个通用寄存器，每个寄存器32位。0号寄存器只读恒为0
* 内存读写的最小单位为1 Byte（8bit）

### 1.1.1 MIPS 指令集

详见 [MIPS手册Ⅱ](../misc/external.md#MIPS 架构) `MIPS Architecture For Programmers Volume II-A - The MIPS32 Instruction Set.rev3.02.pdf`

这里介绍一下本实验中将要实现的部分指令：

------

`01ae5821		addu t3,t5,t6 `

| [31:26]:000000       | [25:21]:01101 | [20:16]:01110 | [15:11]:01011 | [10:6]:00000 | [5:0]:100001 |
| -------------------- | ------------- | ------------- | ------------- | ------------ | ------------ |
| 指令类型：寄存器类型 | rs：t5        | rt：t6        | rd：t3        | 全0          | ADDU         |

操作：`Reg[rd] ⬅ Reg[rs] + Reg[rt] `

------

`25290001		addiu t1,t1,1`

| [31:26]:001001  | [25:21]:01001 | [21:16]:01001 | [15:0]:0000_0000_0000_0001 |
| --------------- | ------------- | ------------- | -------------------------- |
| 指令类型：ADDIU | rs：t1        | rt：t1        | 立即数immediate            |

操作：`Reg[rt] = Reg[rs] + Sign_Extend(immediate)`

注意：该指令中的 u 表示寄存器为无符号的，是为了忽略溢出（和 c 语言的 int 、 unsigned 加法语义一致），立即数仍需符号位扩展。有一部分指令的立即数是0扩展。

------

`8d0c0000 lw t4,0(t0)`

| [31:26]:100011 | [25:21]:01000 | [20:16]:01100 | [15:0]:0000_0000_0000_0000 |
| -------------- | ------------- | ------------- | -------------------------- |
| 指令类型：LW   | base：t0      | rt：t4        | offset                     |

操作：

* `vaddr ⬅ Reg[base] + Sign_Extend(offset)`
* `if(vaddr[1:0] != 2'b0) Exception(Address Exception)`（本实验中，可以保证 vaddr 是4字节对齐）
* `Reg[rt] ⬅ LoadMemory(AddressTranslation(vaddr), size = WORD)`

------

`pc = bfc00704:  	0ff00f00		jal	bfc03c00 <n1_lui_test>`

| [31:26]:000011                 | [25:0]:11_1111_0000_0000_1111_0000_0000 |
| ------------------------------ | --------------------------------------- |
| 指令类型：JAL（jump and link） | instr_index                             |

操作：

* `Reg[31] ⬅ pc + 8`
* 执行下一条指令时：`pc ⬅ {pc[31:28], instr_index, 2'b00}`

JAL指令常用于函数调用。

```asm
# note: in MIPS, branch-type instructions (including j, beq) have a delay slot.

sample1:
beq zero, zero, here # branch if equal
instruction1
instruction2

here: 
instruction3

# sequence is: beq -> instruction1 -> instruction3


sample2:
bne zero, zero, there # branch if not equal
instruction 4
instruction 5
instruction 6

there:
instruction 7

# sequence is: bne -> instruction 4 -> instruction 5
```

本实验需要实现的指令：`lui`	`addu`	`addiu`	`beq`	`bne`	`lw`	`or`	`slt`	`slti`	`sltiu`	`sll`	`sw`	`j` 	`jal`	 `jr`	 `addi`	 `subu`	`sltu`	 `and`	 `andi`	 `nor` 	`ori`	 `xor` 	`xori`	 `sra	`	 `srl`	 `jalr`

### 1.1.2 虚实地址转换

指令代码、寄存器中的地址都是虚拟地址。CPU向内存请求时，需要提供物理地址。

本实验中，只要求实现简单的虚实地址转换。

```verilog
typedef logic [31:0] paddr_t;
typedef logic [31:0] vaddr_t;

paddr_t paddr; // physical address
vaddr_t vaddr; // virtual address

assign paddr[27:0] = vaddr[27:0];
always_comb begin
    unique case (vaddr[31:28])
        4'h8: paddr[31:28] = 4'b0; // kseg0
        4'h9: paddr[31:28] = 4'b1; // kseg0
        4'ha: paddr[31:28] = 4'b0; // kseg1
        4'hb: paddr[31:28] = 4'b1; // kseg1
        default: paddr[31:28] = vaddr[31:28]; // useg, ksseg, kseg3
    endcase
end
```

详见 [MIPS手册Ⅲ](../misc/external.md#MIPS 架构) `MIPS Architecture For Programmers Volume III - The MIPS32 and microMIPS32 Privileged Resource Architecture.rev3.12.pdf page29`

## 1.2 五级流水线

五级流水线的简单示意图如下：

![5-stage](../asset/lab1/5-stage.png)

虚线上方为内存部分的硬件，由测试文件提供。

写 CPU ，就是实现 CPU 的内部，并用事先定好的接口进行封装。

### 1.2.1 Select PC

这一阶段在 Fetch Pipeline Register 前，选择流水线所执行的下一条指令的pc。

可能的来源：

* 顺序的下一条指令（ pc + 4）
* jump 类指令（ `{pc[31:25], instr_index, 2'b00}` ）

等等。

### 1.2.2 Fetch

向 Instruction Memory 提供指令地址，并接收指令。

注意：本实验中，内存有1周期延迟。

其行为类似于：

```verilog
logic [127:0][31:0] memory;
logic [6:0] addr;
logic [31:0] data;
always_ff @(posedge clk) begin
    data <= memory[addr];
end
```

可考虑把接受的数据直接接到下一流水段。

### 1.2.3 Decode

D阶段完成：

* 指令解码，生成控制信号
* 从 Regfile （寄存器文件堆）中读取数据
* 判断是否跳转

### 1.2.4 Execute

E 阶段主要为 ALU 。

### 1.2.5 Memory

M 阶段向 Data Memory 提供数据地址，并接收数据。

注意：本实验中，内存有1周期延迟。

### 1.2.6 Writeback

W 阶段向 Regfile 写数据。

### 1.2.7 Regfile

根据 MIPS 指令集架构，每条指令最多写1个通用寄存器，最多读2个通用寄存器。所以 Regfile 应设计为1个写端口，2个读端口。

参考代码：

```verilog
typedef logic[31:0] word_t;
typedef logic[4:0] creg_addr_t;

module regfile(
	input logic clk,
    input creg_addr_t ra1, ra2, wa3,
    input logic write_enable,
    input word_t wd3
    output word_t rd1, rd2
);
    word_t [31:1] regs, regs_nxt;
    
    // write: sequential logic
    always_ff @(posedge clk) begin
        regs[31:1] <= regs_nxt[31:1];
    end
    for (genvar i = 1; i <= 31; i ++) begin
        always_comb begin
            if (wa3 == i[4:0] && write_enable) begin
                regs_nxt[i[4:0]] = wd3;
            end
        end
    end
    
    
    // read: combinational logic
    assign rd1 = (ra1 == 5'b0) ? '0 : regs[ra1]; // or regs_nxt[ra1] ? 
    assign rd2 = (ra2 == 5'b0) ? '0 : regs[ra2];
    
endmodule
```

### 1.2.8 Pipeline register

五级流水线中，会有阻塞与气泡，所以流水线寄存器需要提供这些机制。

参考代码：

```verilog
typedef struct packed {
    logic a;
} fetch_data_t;

module dreg (
	input logic clk, resetn,
    input fetch_data_t dataF_new,
    input logic enable, flush,
    output fetch_data_t dataF
);
    always_ff @(posedge clk) begin
        if (~resetn | flush) begin // flush overrides enable
            dataF <= '0;
        end else if (enable) begin
            dataF <= dataF_new;
        end
    end
endmodule
```

Tips：

* W阶段流水线寄存器不允许被阻塞
* F阶段流水线寄存器一般不清零
* M阶段流水线寄存器阻塞时（因），E阶段流水线寄存器通常也阻塞（果），防止丢失指令
* E阶段流水线寄存器阻塞时（因），M阶段流水线寄存器通常清零（果），防止指令被执行多次

### 1.2.9 Hazard and Forward

这个部分代码量可能不大，但应该是本实验中最复杂的部分。

主要难点是数据冲突。本实验中，仅需考虑写后读（ RAW ）冲突。请思考：

* 冲突阻塞部分：D 阶段取数据， E、M、W 阶段的写数据会造成冲突。哪些情况应当阻塞流水线？
* 转发部分：哪些指令写通用寄存器？电路图中的哪些数据线可作为转发来源？转发条件是什么？优先级是什么？

分支预测失败的情况比较简单。D阶段判断分支是否跳转；由于 delay slot 的设计，F阶段的指令一定执行。所以，分支跳转不会有额外的惩罚（数据冲突可能存在）。

### 1.2.10 封装 CPU

本实验的 CPU 封装为 SRAM 接口。

```verilog
module mycpu_top (
    input logic clk,
    input logic resetn,  //low active
    input logic[5:0] ext_int,  //interrupt,high active

    output logic inst_sram_en,				// 指令内存总使能
    output logic[3:0] inst_sram_wen,		// 字节写使能，本实验中为全0
    output logic[31:0] inst_sram_addr,		// 地址
    output logic[31:0] inst_sram_wdata,		// 写数据
    input logic[31:0] inst_sram_rdata,		// 读数据
    
    output logic data_sram_en,				// 数据内存总使能
    output logic[3:0] data_sram_wen,		// 字节写使能，本实验中为全0或全1
    output logic[31:0] data_sram_addr,		// 地址
    output logic[31:0] data_sram_wdata,		// 写数据
    input logic[31:0] data_sram_rdata,		// 读数据

    //debug
    output logic[31:0] debug_wb_pc,			// w阶段pc
    output logic[3:0] debug_wb_rf_wen,		// 写使能，一般为全0或全1
    output logic[4:0] debug_wb_rf_wnum,		// 写入的寄存器
    output logic[31:0] debug_wb_rf_wdata	// 写回的数据
);
    // TODO: other circuit
    
endmodule
```

## 1.3 发布包

用 `vivado 2019.2` 打开 `vivado/test1_naive/soc_sram_func/run_vivado/mycpu_prj1/mycpu.xpr` ，添加源文件后，即可开始仿真。

Tips：第一次仿真前，先点击 `IP sources` ，选中所有IP核源文件，右键，点击 `Generate Output Products` 。几秒钟后，跳出 `OK` ，然后再点仿真。

`vivado/test1_naive/soft/obj/test.s` 是测试的反汇编文件，有PC、机器码、汇编码的对应。`soft/` 目录下的其他文件里，可以找到测试的C代码。

`source/mycpu/` 里已经有一些代码，其中：

* `mycpu_top.sv` 是顶层封装文件，仅需把 debug 信号连接上。
* `SRAMTop.sv` 是 SRAM 接口封装文件，需要添加虚实地址翻译。
* `MyCore.sv` 是 CPU 主体流水线文件。

你可以在该目录下随意添加源文件。执行 `add_sources.tcl` 后，它们都会添加到项目里。

`source/include/` 里有一些头文件。

## 1.4 作业与提交

在 `source/mycpu/` 里添加你的代码，实现五级流水线 MIPS CPU 。

本实验需要实现的指令：`lui`	`addu`	`addiu`	`beq`	`bne`	`lw`	`or`	`slt`	`slti`	`sltiu`	`sll`	`sw`	`j` 	`jal`	 `jr`	 `addi`	 `subu`	`sltu`	 `and`	 `andi`	 `nor` 	`ori`	 `xor` 	`xori`	 `sra	`	 `srl`	 `jalr`

通过标准：打开原有 `mycpu.xpr` ，用 `source/add_common.tcl` 添加源文件，上板显示两个绿灯。

实验报告要求：

* 格式：pdf
* 内容：按本文档 1.2 节的思路写即可。写好姓名学号。

提交文件格式：

```
18307130024/
|
|--- source/ (源文件所在目录)
|
|--- report/ (报告所在目录)
```

用 `zip -r 18307130024.zip 18307130024/` 打包。用 `unzip 18307130024.zip` 检查，应在当前目录下有学号目录。

评分：代码 80%，报告 20%

**Deadline：2020年3月21日23:59:59**

## 1.5 思考

1. 流水线寄存器的 flush 信号，需要让所有信号都清零吗？
2. 转发的成本是什么？有哪些限制？（板子上的组合逻辑基本部件为 LUT6 ，6输入1输出，可实现6输入的任何给定逻辑式）
3. 不同指令需要用到的流水线阶段可能不同：加法指令似乎不需要经过 Memory 阶段。能让它跳过 M 阶段吗？