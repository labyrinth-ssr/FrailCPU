#!/bin/bash
for x in bubble_sort coremark crc32 dhrystone quick_sort select_sort sha stream_copy stringsearch
do
	echo "$x without delay"
	make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$x/axi_ram.coe" || exit
	echo "$x with delay"
	make vsim -j VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/$x/axi_ram.coe -p 0.99"  || exit
done
