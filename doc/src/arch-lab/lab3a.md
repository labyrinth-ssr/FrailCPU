# 实验 3a：高速缓存

高速缓存（cache）对于 CPU 性能十分重要。如果没有缓存，流水线做的所有优化都是徒劳的。本次实验需要实现第一级缓存中的数据缓存（L1d）。由于我们的 CPU 的取指和访存的需求基本一致，因此 L1d 可以直接拿来当 L1i 使用。

![缓存层次](../asset/lab3/cache-hierarchy.svg)

上图是目前消费级多核处理器中非常常见的缓存架构。`lscpu -C` 命令可以列出你的 CPU 上各级缓存的信息：

```plaintext
\$ lscpu -C
NAME ONE-SIZE ALL-SIZE WAYS TYPE        LEVEL SETS PHY-LINE COHERENCY-SIZE
L1d       32K     128K    8 Data            1   64        1             64
L1i       32K     128K    8 Instruction     1   64        1             64
L2       256K       1M    4 Unified         2 1024        1             64
L3         8M       8M   16 Unified         3 8192        1             64
```

缓存是利用程序局部性原理的经典例子。32KiB 的 L1d 和 L1i 足以在龙芯杯的性能测试得到 99% 的缓存命中率。

## L1i & L1d

一级缓存分为指令缓存和数据缓存，分别服务于取指和访存阶段。原则上 L1i 是只读的，并且不会有程序在运行过程中写入新的指令[^jit]，因此我们不需要考虑两个缓存之间同步的问题。

## 实现 L1d

接下来我们将分步骤介绍 L1d 的基本结构。

### Cache Line

Cache line 包含一段连续的内存的副本，一般情况下它的大小是一个 2 的幂次，并且起始地址和大小对齐。当缓存从内存中读取出一条 cache line 时，缓存可以利用内存的突发传输特性，从而降低每个字节的平均读取延时。我们使用的 AXI 总线一般可以支持单次最高 16×4 = 64 字节的突发传输，因此我们也建议你使用大小为 64 字节的 cache line。从 L1i 的角度来看，相当于每条 cache line 放了 16 条指令。

如果选择大小为 64 字节的 cache line，那么内部的偏移量（offset）需要 6 位。对于 L1i，由于指令都是和 4 字节对齐的，因此只需要 4 位。

![偏移量](../asset/lab3/offset.svg)

![偏移量和 4 字节对齐](../asset/lab3/offset-pad.svg)

### Cache Set

### Cache Line Tag

## Cache Bus (CBus)

CBus 是对 AXI 总线突发传输接口的简化。

## 模块级测试

本次实验会使用 Verilator 对缓存做专门的测试。

## 实验提交

```plaintext
18307130024/
├── report/   （报告所在目录）
├── source/   （源文件所在目录）
└── verilate/ （仿真代码所在目录）
```

用 `zip -r 18307130024.zip 18307130024/` 打包。用 `unzip 18307130024.zip` 检查，应在当前目录下有学号目录。

### 通过标准

TODO

### 实验报告要求

* 格式：PDF
* 内容：
    * 简要描述你设计的缓存。
    * 如果你尝试做了优化，请举例说明优化的效果。
    * 写好姓名学号。附上测试通过时的照片或截图。

### 截止时间

**2021 年 5 月 9 日 23:59:59**

## *思考题

* 在先前 `lscpu -C` 的例子中，你可能注意到 L1i/L1d 的 set 数量（SETS）只有 64，远小于 L2 的 set 数量，但是 L1i/L1d 的关联数（WAYS）却反而比 L2 大。为什么它不选择把 L1i/L1d 的关联数降到 4，并且把 set 数量提高到 128 呢？
* 文档中 `lscpu -C` 的输出来自 Intel 的 Coffee Lake 微架构的 i5 8300H。该 CPU 的 L3 是一个 (strictly) inclusive cache[^inclusive]。结合 [WikiChip](https://en.wikichip.org/wiki/intel/microarchitectures/coffee_lake#Memory_Hierarchy) 上的信息，请尝试解释为什么 L3 的关联数是 16。

---

[^jit]: 但实际上像 JVM、Javascript V8 这种利用 JIT 技术的软件可能会有这种需求。MIPS 架构中提供了 `CACHE` 指令来解决这个问题。

[^inclusive]: 参见 [Wikipedia](https://en.wikipedia.org/wiki/CPU_cache#INCLUSIVE) 以及网上的资料。
