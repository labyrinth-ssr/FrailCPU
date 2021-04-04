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

接下来我们将介绍 L1d 的基本结构。

### Cache Line

Cache line 包含一段连续的内存的副本，一般情况下它的大小是一个 2 的幂次，并且起始地址和大小对齐。当缓存从内存中读取出一条 cache line 时，缓存可以利用内存的突发传输特性，从而降低每个字节的平均读取延时。我们使用的 AXI 总线一般可以支持单次最高 16×4 = 64 字节的突发传输，因此我们也建议你使用大小为 64 字节的 cache line。从 L1i 的角度来看，相当于每条 cache line 放了 16 条指令。

如果选择大小为 64 字节的 cache line，那么内部的偏移量（offset）需要 6 位。对于 L1i，由于指令都是和 4 字节对齐的，因此只需要 4 位。

![偏移量](../asset/lab3/offset.svg)

![偏移量和 4 字节对齐](../asset/lab3/offset-pad.svg)

### Cache Set

前面说的 cache line 是缓存和内存交互的基本单元。相当于缓存将内存视为一大堆 cache line 的集合。之后我们需要考虑如何在缓存中索引 cache line。

最常见的做法是把缓存分为若干个桶，每个桶内可以存放一定数量的 cache line，有点类似于哈希表。这些桶在缓存的术语中叫做 cache set。一般地址中除去 offset 后最低的几位会被拿来当作 cache set 的索引（index）：

![索引和偏移量](../asset/lab3/index-offset.svg)

每个 cache set 内能同时存储的 cache line 条数称为关联度（associativity）。显然关联度至少为 1，常见的关联度有 2、4、8（也就是所谓的 2 路、4 路、8 路缓存）。由于很多的 cache line 会被映射到同一个 cache set 内，我们必须用地址中剩下的位对它们进行区分。这些位通常也称作标签（tag）：

![标签、索引和偏移量](../asset/lab3/tag-index-offset.svg)

当我们索引 cache line 时，通常会在 cache set 内并行地比较 tag。因此，关联度太大会导致缓存中比较器消耗的硬件资源过多，反而会降低缓存性能。

> **为什么使用低位作为索引值？**
>
> 看一个现实生活中的例子：
>
> <img alt="杨浦区某快餐店" src="../asset/lab3/mcdonalds.jpg" width=65% />
> <center class="fig-caption">（杨浦区某快餐店的外卖暂存区。右下角应该是数字 “9”）</center>
>
> 上图中货架上每个数字下面写着 “订单尾号”。
>
> 该快餐店的订单号是按顺序生成的。因此用低位作为索引有助于充分利用货架上的每个隔间。也正因为顺序生成的订单号，所以在一段时间内产生的外卖的订单号的高位都是一样的。如果用高位，就会导致大量的外卖放在同一层内。

总结一下：

* offset 用于 cache line 内的寻址。
* index 用于索引到 cache line。
* tag 用于区分不同的 cache line。

### 替换策略

缓存的大小通常远小于内存的大小，所以一个程序运行过程中所需要用到的所内存大概率不能都放入缓存中。缓存的主要目标是把程序近期会用到的内存全部装入缓存，这些内存通常也称为工作集（working set）。因此，缓存经常需要把不常用的 cache line 从缓存中清出去，为接下来需要访问的 cache line 腾出空间。

举个例子，对于一个 4 路缓存，某个 cache set 已经有 4 条 cache line 了，然后 CPU 访问的下一个地址对应的 cache line 不在缓存中，但也是映射到这个 cache set 的。此时缓存必须把这个 cache set 内已有的某条 cache line 替换掉，从而能够存放新的 cache line。那么此时应该将哪条 cache line 替换出去呢？

相比各位在 ICS 课上已经了解过各种替换策略了，因此这里不会再一一列举。简单来说，如果我们知道程序的访存顺序，那么我们只需要将下次访问时间最晚的 cache line 替换掉即可。这个贪心算法可以证明是最优的。但显然我们无法准确得知程序的行为。LRU 算法和它的各种变种是缓存中常用的替换算法。LRU 在大多数情况下的效果都比较接近最优贪心算法的效果[^lru]。最原始的 LRU 算法需要维护 cache set 内每条 cache line 的顺序，在硬件上实现可能比较消耗资源，因此出现了一些 LRU 的变种算法。此外，随机替换策略在缓存关联度足够大的时候也有不错的表现。并且随机替换不需要在访存缓存时更新替换算法的状态，也不需要每个 cache set 都存放一些额外信息。相比于 LRU 系列，随机替换可以节约大量的硬件资源。

本次实验中你可以实现任意的替换策略。

### 状态机

### 存储

## 缓存总线（CBus）

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

**2021 年 5 月 10 日 12:00**

## *思考题

* 在关联度为 $2^k$ 的缓存中实现 LRU 算法时，每个 cache set 最少需要为 LRU 算法记录多少位的额外信息？
* 在先前 `lscpu -C` 的例子中，你可能注意到 L1i/L1d 的 set 数量（SETS）只有 64，远小于 L2 的 set 数量，但是 L1i/L1d 的关联数（WAYS）却反而比 L2 大。为什么它不选择把 L1i/L1d 的关联数降到 4，并且把 set 数量提高到 128 呢？
* 文档中 `lscpu -C` 的输出来自 Intel 的 Coffee Lake 微架构的 i5 8300H。该 CPU 的 L3 是一个 (strictly) inclusive cache[^inclusive]。结合 [WikiChip](https://en.wikichip.org/wiki/intel/microarchitectures/coffee_lake#Memory_Hierarchy) 上的信息，请尝试解释为什么 L3 的关联数是 16。

---

[^jit]: 但实际上像 JVM、Javascript V8 这种利用 JIT 技术的软件可能会有这种需求。MIPS 架构中提供了 `CACHE` 指令来解决这个问题。

[^lru]: 如果是在链表上做更新，Sleator & Tarjan 证明了 LRU 算法和最优算法的操作数是同一个级别的：[“Amortized Efficiency of List Update and Paging Rules”](https://dl.acm.org/doi/10.1145/2786.2793)。

[^inclusive]: 参见 [Wikipedia](https://en.wikipedia.org/wiki/CPU_cache#INCLUSIVE) 以及网上的资料。
