################################################################################
#
# Makefile for nco block
#
# - Run `make all` to build everything but not run
# - Run `make run` to build and run the simulation
# - Run 'make plot` to output plot images
#
#
# Author     Date       Comments
# Chris M.   ??/??/??   Initial revision
# Chris M.   09/28/25   Migrate to Gentoo setup.
#
#

# On my PC, this is where I installed ghdl 6.0.0 with gcc code generation
# GHDL = /opt/ghdl-6.0.0-dev/bin/ghdl

 
GHDL = /usr/local/bin/ghdl

OSVVM_DIR = $(HOME)/VHDL_LIBS/GHDL-7.0.0

GHDLFLAGS = --std=08 -Wuseless -Werror -fsynopsys --workdir=work -P$(OSVVM_DIR)

RUNFLAGS= --vcd=work/NCO_TB.vcd --stop-time=100sec

SRC = nco.vhd nco_tb.vhd


all:
	$(MAKE) nco_tb

# 
nco_tb: nco.vhd nco_tb.vhd | work
	$(GHDL) -a $(GHDLFLAGS) nco.vhd
	$(GHDL) -a $(GHDLFLAGS) nco_tb.vhd
	$(GHDL) -e $(GHDLFLAGS) nco_tb

run:  nco_tb
	$(GHDL) -r nco_tb $(RUNFLAGS) 
	@echo "Running verify_nco.py"
clean:
	$(GHDL) --clean --std=08 --workdir=work/
	rm -rfd work/*

work:
	mkdir -p work

plot: | square.txt sawtooth.txt
	python3 verify_nco.py

.PHONY: clean	
