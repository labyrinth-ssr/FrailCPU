SV = verilator

SV_TARGET ?= refcpu/VTop

SV_PREFIX = VModel
SV_BUILD = build/verilated/$(SV_TARGET)#  # build/refcpu/VTop
SV_ROOT := $(shell dirname $(SV_TARGET))# # refcpu. NOTE: builtin $(dir ...) will leave the final "/".
SV_NAME := $(notdir $(SV_TARGET))#        # VTop
SV_MKFILE = $(SV_BUILD)/$(SV_PREFIX).mk#  # build/refcpu/VTop/VTop.mk
SV_VTOP = source/$(SV_TARGET).sv#         # source/refcpu/VTop.sv

SV_FILES := \
	$(wildcard source/util/*) \
	$(wildcard source/ram/*) \
	$(wildcard source/include/*) \
	$(shell find 'source/include/$(SV_ROOT)' -type f -name '*.svh') \
	$(shell find 'source/$(SV_ROOT)' -type f -name '*.sv')

SV_INCLUDES = \
	-y source/util/ \
	-y source/ram/ \
	-y source/include/ \
	-y source/$(SV_ROOT)/ \
	-y source/$(SV_ROOT)/*/

SV_WARNINGS = \
	-Wall -Wpedantic \
	-Wno-IMPORTSTAR
	# add warnings that you wanna ignore.

SV_FLAGS = \
	--cc -sv --relative-includes \
	--output-split 6000 \
	--trace-fst --trace-structs \
	--Mdir $(SV_BUILD) \
	--top-module $(SV_NAME) \
	--prefix $(SV_PREFIX) \
	$(SV_INCLUDES) \
	$(SV_WARNINGS)

ifeq ($(USE_CLANG), 1)
SV_FLAGS += -CFLAGS -stdlib=libc++
endif

$(SV_MKFILE): $(SV_FILES)
	@mkdir -p $(SV_BUILD)
	$(SV) $(SV_FLAGS) $(SV_VTOP)

.PHONY: verilate

verilate: $(SV_MKFILE)
