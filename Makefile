.PHONY: help clean

help:
	@echo 'Hello, world!'

clean:
	@rm -rf ./build/*
	@touch ./build/.gitkeep

include verilate/Makefile.verilate.mk
include verilate/Makefile.vsim.mk
