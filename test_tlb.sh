#!/bin/bash
echo "tlb without delay"

make vsim -j VSIM_ARGS="-m vivado/test_new_instr/tlb.coe -f tlb.fst" || exit
# echo "cache with delay"
# make vsim -j VSIM_ARGS="-m vivado/test_new_instr/cache.coe -p 0.99  "  || exit