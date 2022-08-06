#!/bin/bash
echo "$1 without delay"

<<<<<<< HEAD
make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe -f $1.fst -t $1.txt" || exit
=======
make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe " || exit
>>>>>>> origin/bp
# echo "$1 with delay"
# make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$1/axi_ram.coe -p 0.99 -f coremark.fst"  || exit