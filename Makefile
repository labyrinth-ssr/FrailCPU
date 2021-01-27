.PHONY: help clean

help:
	@echo 'Hello, world!'

clean:
	rm -rf ./build/

include verilate/Makefile.verilate.mk
