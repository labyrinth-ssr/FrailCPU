SV = verilator
SV_TARGET ?= RefCPU
SV_MKFILE = build/V$(SV_TARGET).mk
SV_ROOT := $(shell echo $(SV_TARGET) | tr A-Z a-z)
SV_VTOP = ./source/$(SV_ROOT)/VTop.sv

SV_FILES := \
	$(wildcard ./source/util/*.sv) \
	$(wildcard ./source/include/*.svh) \
	$(wildcard ./source/include/$(SV_ROOT)/*.svh) \
	$(wildcard ./source/$(SV_ROOT)/*.sv) \
	$(wildcard ./source/$(SV_ROOT)/**/*.sv)

SV_INCLUDE = \
	-y ./source/util/ \
	-y ./source/include/ \
	-y ./source/$(SV_ROOT)/ \
	-y ./source/$(SV_ROOT)/*/

SV_WARNINGS = \
	-Wall \
	-Wno-IMPORTSTAR

SV_FLAGS = \
	--cc -sv --relative-includes \
	--output-split 6000 \
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
