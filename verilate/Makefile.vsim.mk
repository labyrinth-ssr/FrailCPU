VERILATOR = /usr/share/verilator/include

SV_READY = $(SV_MKFILE)

VMAIN = build/vmain
VROOT = $(SV_ROOT)
VTARGET = ./build/V$(SV_TARGET)__ALL.a
VINCLUDE = ./verilate/include
VSOURCE = ./verilate/source

CXX_TARGET_FILES := $(wildcard $(VSOURCE)/$(VROOT)/*.cpp)
CXX_FILES := \
	$(wildcard $(VSOURCE)/*.cpp) \
	$(CXX_TARGET_FILES) \
	$(VERILATOR)/verilated.cpp \
	$(VERILATOR)/verilated_fst_c.cpp

CXX_HEADERS := \
	$(wildcard $(VINCLUDE)/*.h) \
	$(wildcard $(VINCLUDE)/thirdparty/*.h) \
	$(wildcard $(VINCLUDE)/$(VROOT)/*.h)

CXX_TARGET_LIBS := $(addprefix ./build/, $(CXX_TARGET_FILES:%.cpp=%.o))
CXX_LIBS := $(addprefix ./build/, $(CXX_FILES:%.cpp=%.o))

CXX_INCLUDES = \
	-I./build/ \
	-I$(VINCLUDE) \
	-I$(VERILATOR) \
	-I$(VERILATOR)/vltstd/

CXX_WARNINGS = \
	-Wall -Wextra \
	-Wno-aligned-new \
	-Wno-sign-compare \
	-Wno-unused-const-variable

CXXFLAGS += \
	-std=c++17 \
	-lz -g \
	$(CXX_INCLUDES) \
	$(CXX_WARNINGS)

$(CXX_TARGET_LIBS): $(SV_READY)
$(CXX_LIBS): ./build/%.o : %.cpp $(CXX_HEADERS)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $< -c -o $@

$(VTARGET): $(SV_READY)
	cd build; $(MAKE) -f $(notdir $(SV_MKFILE))

$(VMAIN): $(CXX_LIBS) $(VTARGET)
	$(CXX) $(CXXFLAGS) $^ -o $@

.PHONY: vbuild vsim vsim-gdb
vbuild: $(VMAIN)
vsim: $(VMAIN)
	./$(VMAIN)

vsim-gdb: $(VMAIN)
	gdb ./$(VMAIN)
