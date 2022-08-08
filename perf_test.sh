#!/bin/bash
echo "$1 without delay"

make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe" || exit
echo "$1 with delay"
make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe -p 0.99 -f coremark.fst"  || exit