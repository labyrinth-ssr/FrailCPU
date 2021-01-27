SV = verilator
SV_TARGET ?= RefCPU
SV_MKFILE = build/V$(SV_TARGET).mk
SV_DIR = $(shell echo $(SV_TARGET) | tr A-Z a-z)
SV_VTOP = ./source/$(SV_DIR)/VTop.sv

SV_FILES = \
	$(wildcard ./source/util/*.sv) \
	$(wildcard ./source/include/*.svh) \
	$(wildcard ./source/include/$(SV_DIR)/*.svh) \
	$(wildcard ./source/$(SV_DIR)/**/*.sv)

SV_INCLUDE = \
	-y ./source/util/ \
	-y ./source/include/ \
	-y ./source/$(SV_DIR)/ \
	-y ./source/$(SV_DIR)/*/

SV_WARNINGS = \
	-Wall \
	-Wno-IMPORTSTAR

SV_FLAGS = \
	--cc -sv --relative-includes \
	--Mdir build \
	--top-module VTop \
	--prefix V$(SV_TARGET) \
	--trace-fst --trace-structs \
	$(SV_INCLUDE) \
	$(SV_WARNINGS)

$(SV_MKFILE): $(SV_VTOP) $(SV_FILES)
	$(SV) $(SV_FLAGS) $(SV_VTOP)

.PHONY: verilate
verilate: $(SV_MKFILE)
