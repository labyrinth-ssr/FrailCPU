#!/bin/bash
echo "linux without delay"

make vsim -j VSIM_ARGS="-m vivado/test_new_instr/vmlinux.coe -f linux.fst -t linux.txt" || exit
# echo "cache with delay"
# make vsim -j VSIM_ARGS="-m vivado/test_new_instr/cache.coe -p 0.99  "  || exit