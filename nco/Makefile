################################################################################
#
# Makefile for nco block
#
# Author     Date       Comments
# Chris M.   ??/??/??   Initial revision
# Chris M.   09/28/25   Migrate to Gentoo setup.
#

OSVVM_DIR = $(HOME)/VHDL_LIBS/GHDL-5.0.1/

GHDLFLAGS = --std=08 -Wuseless -Werror -fsynopsys --workdir=work -P$(OSVVM_DIR)

RUNFLAGS= --vcd=work/NCO_TB.vcd --stop-time=3sec

SRC = nco.vhd nco_tb.vhd


all:
	$(MAKE) nco_tb

nco_tb: nco.vhd nco_tb.vhd | work
	ghdl -a $(GHDLFLAGS) nco.vhd
	ghdl -a $(GHDLFLAGS) nco_tb.vhd
	ghdl -e $(GHDLFLAGS) nco_tb

run:  nco_tb
	ghdl -r nco_tb $(RUNFLAGS) 

clean:
	ghdl --clean --std=08 --workdir=work/

work:
	mkdir -p work

.PHONY: clean	
