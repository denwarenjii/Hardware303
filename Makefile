GHDLFLAGS= --std=08 -Wuseless -Werror -fsynopsys --workdir=work -P/home/chris/vhdl
GHDLRUNFLAGS= --vcd=work/NCO_TB.vcd --stop-time=3sec

all:
	ghdl -a $(GHDLFLAGS) nco.vhd
	ghdl -a $(GHDLFLAGS) nco_tb.vhd
	ghdl -e $(GHDLFLAGS) nco_tb
	ghdl -r nco_tb $(GHDLRUNFLAGS) 
