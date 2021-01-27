VERILATOR = /usr/share/verilator/include

SV_READY = $(SV_MKFILE)

VMAIN = build/vmain
VROOT = $(SV_ROOT)
VTARGET = ./build/V$(SV_TARGET)__ALL.a
VINCLUDE = ./verilate/include
VSOURCE = ./verilate/source

CXX_FILES := \
	$(VSOURCE)/main.cpp \
	$(wildcard $(VSOURCE)/$(VROOT)/*.cpp) \
	$(VERILATOR)/verilated.cpp \
	$(VERILATOR)/verilated_fst_c.cpp

CXX_HEADERS := \
	$(VINCLUDE)/common.h \
	$(wildcard $(VINCLUDE)/$(VROOT)/*.h)

CXX_LIBS := $(addprefix ./build/, $(CXX_FILES:%.cpp=%.o))

CXX_INCLUDES = \
	-I./build/ \
	-I$(VINCLUDE) \
	-I$(VERILATOR) \
	-I$(VERILATOR)/vltstd/

CXX_WARNINGS = \
	-Wall -Wextra \
	-Wno-aligned-new \
	-Wno-sign-compare

CXXFLAGS += \
	-std=c++14 \
	-lz \
	$(CXX_INCLUDES) \
	$(CXX_WARNINGS)

$(CXX_LIBS): ./build/%.o : %.cpp $(CXX_HEADERS) $(SV_READY)
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $< -c -o $@

$(VTARGET): $(SV_READY)
	cd build; $(MAKE) -f $(notdir $(SV_MKFILE))

$(VMAIN): $(CXX_LIBS) $(VTARGET)
	$(CXX) $(CXXFLAGS) $^ -o $@

.PHONY: vbuild vsim
vbuild: $(VMAIN)
vsim: $(VMAIN)
	./$(VMAIN)
