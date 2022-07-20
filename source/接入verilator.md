# 1 把信号暴露给 verilator

首先在 writeback 模块中找到需要接入 verilator 的信号（pc 啊啥的），然后在信号的后面加`/* verilator public_flat_rd */`

```verilog
module Writeback();
    logic [31:0] pc /* verilator public_flat_rd */;
endmodule
```

# 2 在C++中访问信号

假如你的 Mycore 中的 writeback 是这样写的，且 writeback 模块中有 pc 信号：

```verilog
module MyCore();
    Writeback wb();
endmodule
```

因为在 VTop 中例化了一个 `Mycore core` ，所以从 VTop 访问 pc 的跨时钟写法应该是 `core.wb.pc` ，但 `/* verilator public_flat_rd */ ` 是去层次化的声明，不能有 `.` 所以 verilator 会转化成 `core__DOT__wb__DOT__pc` (`.` 变成了 `__DOT__`)

所以你可以这样访问信号：

```c++
/verilate/source/mycpu/VTop/mycpu.cpp

auto MyCPU::get_writeback_pc() const -> addr_t {
    /**
     * TODO (Lab2) retrieve PC from verilated model :)
     */
    return VTop->core__DOT__wb__DOT__pc;  // 访问 PC
}
```

然后请把其他的 get 函数也一并写好

# 3 支持双发射

现在已经在 /verilate/source/mycpu/VTop/mycpu.cpp 中写好了 4 个 get 函数，

- 我们只需要把这 4 个函数复制一下，来 get 另一条提交的指令的信号

- 修改 print_writeback() 函数，仿照格式对另一条提交的指令进行一次 text_dump() 即可