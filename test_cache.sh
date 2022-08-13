#!/bin/bash
echo "cache without delay"

make vsim -j VSIM_ARGS="-m vivado/test_new_instr/cache.coe -f cache.fst -t log.txt" || exit
# echo "cache with delay"
# make vsim -j VSIM_ARGS="-m vivado/test_new_instr/cache.coe -p 0.99  "  || exit