#!/bin/bash
echo "pmon without delay"

make vsim -j VSIM_ARGS="-m vivado/test_new_instr/gzrom.coe -f pmon.fst -t pmon.txt" || exit
# echo "cache with delay"
# make vsim -j VSIM_ARGS="-m vivado/test_new_instr/cache.coe -p 0.99  "  || exit