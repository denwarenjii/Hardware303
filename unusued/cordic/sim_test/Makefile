#
GHDL         = /usr/local/bin/ghdl

OSVVM_DIR    = $(HOME)/VHDL_LIBS/GHDL-7.0.0
GHDLFLAGS    = --std=08 -Wuseless -Wunused -fsynopsys --workdir=work -P$(OSVVM_DIR)
GHDLRUNFLAGS = --ieee-asserts=disable --stop-time=1000ns --vcd=work/cordic_tb.vcd

SRCS := AdderSubtracter.vhd \
	AddSub.vhd	    \
	AnsiEscape.vhd	    \
	FixedLib.vhd        \
	CordicStage.vhd     \
	Cordic.vhd          \
	Cordic_TB.vhd       \

all: | work
	$(MAKE) cordic_tb

cordic_tb: | work $(SRCS)
	$(GHDL) -a $(GHDLFLAGS) AdderSubtracter.vhd
	$(GHDL) -a $(GHDLFLAGS) AddSub.vhd
	$(GHDL) -a $(GHDLFLAGS) AnsiEscape.vhd
	$(GHDL) -a $(GHDLFLAGS) FixedLib.vhd
	$(GHDL) -a $(GHDLFLAGS) CordicStage.vhd
	$(GHDL) -a $(GHDLFLAGS) Cordic.vhd
	$(GHDL) -a $(GHDLFLAGS) Cordic_TB.vhd
	$(GHDL) -e $(GHDLFLAGS) cordic_tb

clean:
	$(GHDL) --clean --std=08 --workdir=work/
	rm -rfd work/*

run: cordic_tb
	$(GHDL) -r $< $(GHDLRUNFLAGS)

work:
	mkdir -p work

.PHONY: clean
