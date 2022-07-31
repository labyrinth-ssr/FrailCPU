#make vsim-gdb -j VSIM_OPT=0 VSIM_ARGS="-m vivado/test5/soft/perf_func/obj/coremark/axi_ram.coe"-f mg.fst
#make vsim-gdb -j VSIM_OPT=0 VSIM_ARGS="-m ~/nscscc-group/func_test_v0.01/soft/memory_game/obj/axi_ram.coe "
make vsim -j VSIM_OPT=0 VSIM_ARGS="-m ~/nscscc-group/func_test_v0.01/soft/memory_game/obj/axi_ram.coe -f mg2.fst"