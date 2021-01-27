/**
 * some helper macros for VTop.
 *
 * see <https://github.com/rsd-devel/rsd/blob/master/Processor/Src/SysDeps/Verilator/VerilatorHelper.sv>
 */

`ifndef __ACCESS_SVH__
`define __ACCESS_SVH__

`define STRUCT_ACCESSOR(struct_name, member_name, return_type) \
    function return_type struct_name``_``member_name(struct_name e); \
        /* verilator public */ \
        logic _unused_ok = &e; \
        return return_type'(e.member_name); \
    endfunction

`endif
