###############################################################################
# Makefile for WBlock
#
# Revision History:
#    Date:         Author:    Description:
#    30 May 2025   Chris M.   Initial revision
#
###############################################################################

GHDL         = /usr/local/bin/ghdl

OSVVM_DIR    = $(HOME)/VHDL_LIBS/GHDL-7.0.0
GHDLFLAGS    = --std=08  -Wall -Wshared -Wuseless -Wunused -fsynopsys --workdir=work -P$(OSVVM_DIR)
GHDLRUNFLAGS = --ieee-asserts=disable --stop-time=10ns

# --vcd=work/wblock_tb.vcd

SRCS := WBlock.vhd	\
	WBlock_TB.vhd

all: | work
	$(MAKE) wblock_tb

wblock: | work
	$(GHDL) -a $(GHDLFLAGS) AnsiEscape.vhd
	$(GHDL) -a $(GHDLFLAGS) FixedLib.vhd
	$(GHDL) -a $(GHDLFLAGS) AdderSubtracter.vhd
	$(GHDL) -a $(GHDLFLAGS) AddSub.vhd
	$(GHDL) -a $(GHDLFLAGS) FixedLib.vhd
	$(GHDL) -a $(GHDLFLAGS) CordicStage.vhd
	$(GHDL) -a $(GHDLFLAGS) Cordic.vhd
	$(GHDL) -a $(GHDLFLAGS) WBlock.vhd

wblock_tb : wblock | work $(SRCS)
	$(GHDL) -a $(GHDLFLAGS) WBlock_TB.vhd
	$(GHDL) -e $(GHDLFLAGS) wblock_tb

moogfilterstage: wblock | work 
	$(GHDL) -a $(GHDLFLAGS) MoogFilterStage.vhd

moogfilterstage_tb : | work
	$(GHDL) -a $(GHDLFLAGS) MoogFilterStage_TB.vhd
	$(GHDL) -e $(GHDLFLAGS) moogfilterstage_tb

clean:
	$(GHDL) --clean --std=08 --workdir=work/
	rm -rfd work/*

run_wblock_tb: wblock_tb
	$(GHDL) -r $< $(GHDLRUNFLAGS) --vcd=work/$<.vcd

run_moogfilterstage_tb: moogfilterstage_tb
	$(GHDL) -r $< $(GHDLRUNFLAGS) --vcd=work/$<.vcd

work:
	mkdir -p work

.PHONY: clean wblock moogfilterstage

