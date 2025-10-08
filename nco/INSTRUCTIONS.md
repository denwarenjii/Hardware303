# Instructions to run/test NCO

Last edited: 09/28/2025

## Testbench

The NCO test bench instantiates a 16-bit, 44.1 KHz NCO entity and tests
the square and sawtooth outputs at various frequencies. The testbench is built
and run with `make run`. 

When testing the square and sawtooth output, one unsigned 16-bit integer is
printed per timestep to `sawtooth.txt` and `square.txt` respectively. These
integers represent the ampltiude of the output wave. The waveforms can then
be visualized with `make plot`, which runs a simple python script that shows
the waveforms in the time and frequency domains.