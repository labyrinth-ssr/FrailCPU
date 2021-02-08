Verilator-related files.

## Make Arguments

* `VSIM_ARGS`: pass arguments to the execution of `vmain`.
* `VSIM_OPT`: set to 1 to use `-O2 -march=native` options in compiling testbench code.

## Tricks

### Using `nameof` with Verilog enumerations

NOTE: `nameof` requires C++17.

* Put `/* verilator public */` after the `typedef` of the `enum`.
* Re-elaborate RTL design and you'll see an enum in `Vxxx___024unit.h`.
* (optional) Give the enum an alias name.
* Use `nameof::nameof_enum(var).data()` to get the corresponding name for enum variable `var`.

## NOTE

* `__PVT__` means "private" in verilated models.
