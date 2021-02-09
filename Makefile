.PHONY: help clean

help:
	@echo 'Hello, world!'

clean:
	@rm -rf ./build/*
	@touch ./build/.gitkeep

USE_CLANG ?= 0

ifeq ($(USE_CLANG), 1)
ifeq ($(shell which clang++-10),)
CXX=clang++
else
CXX=clang++-10  # for Ubuntu 18.04
endif
endif

include verilate/Makefile.verilate.mk
include verilate/Makefile.vsim.mk
