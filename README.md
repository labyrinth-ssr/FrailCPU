# Introduction to Computer Systems (II)

Spring 2021, Fudan University.

## Prerequisites

* Xilinx Vivado (= 2019.2, HLx version)
* Verilator (≥ 4.028)
* `build-essential`
    * GNU make
    * C++17 capable compiler: GNU C++ (≥ 9.0.0) or LLVM clang (≥ 6.0.0)
    * gdb
* GTKWave
* `libz-dev` (or the correct devel packege for zlib on your Linux distribution)

On Ubuntu 20.04:

```shell
apt update
apt install -y build-essential gdb gtkwave libz-dev verilator
```

On Ubuntu 18.04:

Because Verilator 3.x on Ubuntu 18.04 is outdated, we need to install a newer version from SiFive. First, download the `.deb` package file from <https://github.com/sifive/verilator/releases> (or eLearning if your network connection to GitHub is not stable) and save it to `verilator4.deb`. And then execute the following commands as root:

```shell
apt update
apt install -y build-essential gdb gtkwave libz-dev clang-9
dpkg -i verilator4.deb
ln -s /usr/local/share/verilator /usr/share/
```

NOTE: there's no GCC 9 officialy on Ubuntu 18.04, so we installed clang instead. As a result, every time you run `make vsim`, you have to specify `CXX=clang++-9` in command line. For example:

```shell
make vsim -j8 CXX=clang++-9
```

## File Organization

* `misc/`: miscellaneous files.
* `doc/`: lab handouts.
* `source/`: SystemVerilog source files.
* `vivado/`: SoC and testbenches on Vivado.
* `verilate/`: C++ source files for verilated simulation.
* `build/`: temporary build files.
