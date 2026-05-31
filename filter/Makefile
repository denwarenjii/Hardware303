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
GHDLFLAGS    = --std=08 -Wuseless -Wunused -fsynopsys --workdir=work -P$(OSVVM_DIR)
GHDLRUNFLAGS = --ieee-asserts=disable --stop-time=1000ns --vcd=work/cordic_tb.vcd

SRCS := WBlock.vhd	\
	WBlock_TB.vhd

all: | work
	$(MAKE) wblock_tb

wblock_tb : | work $(SRCS)
	$(GHDL) -a $(GHDLFLAGS) ANSIEscape.vhd
	$(GHDL) -a $(GHDLFLAGS) WBlock.vhd
	$(GHDL) -a $(GHDLFLAGS) WBlock_TB.vhd
	$(GHDL) -e $(GHDLFLAGS) wblock_tb

clean:
	$(GHDL) --clean --std=08 --workdir=work/
	rm -rfd work/*

run: wblock_tb
	$(GHDL) -r $< $(GHDLRUNFLAGS)

work:
	mkdir -p work

.PHONY: clean

