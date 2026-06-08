###############################################################################
# Makefile for WBlock
#
# Revision History:
#    Date:         Author:    Description:
#    30 May 2025   Chris M.   Initial revision
#
# TODO:
# 	- Figure out how to use GHDL's dependency generation shit
# 	- Don't copy all the supporting files here?
#
###############################################################################

GHDL := ghdl

OSVVM_DIR := $(HOME)/VHDL_LIBS/GHDL-7.0.0
GHDLFLAGS := --std=08  -Wall -Wshared -Wuseless -Wunused -fsynopsys --workdir=work -P$(OSVVM_DIR)
GHDLRUNFLAGS := --ieee-asserts=disable --stop-time=100ns
TB_BINARY := moogfilterstage_tb

SRCS := AnsiEscape.vhd \
	FixedLib.vhd \
	AdderSubtracter.vhd \
	AddSub.vhd \
	FixedLib.vhd \
	CordicStage.vhd \
	Cordic.vhd \
	WBlock.vhd \
	MoogFilterStage.vhd \
	MoogFilterStage_TB.vhd

all: | work
	$(MAKE) $(TB_BINARY)

moogfilterstage_tb: | work $(SRCS)
	$(GHDL) -a $(GHDLFLAGS) AnsiEscape.vhd
	$(GHDL) -a $(GHDLFLAGS) FixedLib.vhd
	$(GHDL) -a $(GHDLFLAGS) AdderSubtracter.vhd
	$(GHDL) -a $(GHDLFLAGS) AddSub.vhd
	$(GHDL) -a $(GHDLFLAGS) FixedLib.vhd
	$(GHDL) -a $(GHDLFLAGS) CordicStage.vhd
	$(GHDL) -a $(GHDLFLAGS) Cordic.vhd
	$(GHDL) -a $(GHDLFLAGS) WBlock.vhd
	$(GHDL) -a $(GHDLFLAGS) MoogFilterStage.vhd
	$(GHDL) -a $(GHDLFLAGS) MoogFilterStage_TB.vhd
	$(GHDL) -e $(GHDLFLAGS) $(TB_BINARY)

run: $(TB_BINARY) | work
	$(GHDL) -r $< $(GHDLRUNFLAGS) --vcd=work/$<.vcd

clean:
	$(GHDL) --clean --std=08 --workdir=work/
	rm -rfd work/*

work:
	mkdir -p work

.PHONY: clean
