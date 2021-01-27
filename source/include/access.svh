/**
 * some helper macros for VTop.
 *
 * see <https://github.com/rsd-devel/rsd/blob/master/Processor/Src/SysDeps/Verilator/VerilatorHelper.sv>
 */

`ifndef __ACCESS_SVH__
`define __ACCESS_SVH__

`define STRUCT_ACCESSOR(struct_name, member_name, member_type) \
    function member_type struct_name``_``member_name(struct_name e); \
        /* verilator public */ \
        logic unused = &e; \
        return member_type'(e.member_name); \
    endfunction

`endif
