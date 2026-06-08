---
fontfamily: roboto-serif

geometry:
- top=.5in
- bottom=.5in
- left=.5in
- right=.5in
fontsize: 10pt
linestretch: 1.25
---

# Hardware303

Christian Miranda

I have implemented a partial replica of the Roland TB-303 in VHDL. The Roland
TB-303 is an analog bass line synthesizer noted for its characteristic filter -
a diode ladder filter - that is hard to replicate in software. This design uses
a Moog ladder filter however, since it is much more well known, and does not
require significant analog analysis to replicate the sound of the TB-303 as a
diode ladder would.


## Theory of Operation

### Basic Blocks

The Roland TB-303 consists of the following blocks:
    - Oscillator: a voltage-controlled oscillator that creates a square or
                 sawtooth wave in the bass clef range.
    - Filter: a resonant low-pass filter meant to mimic the sound of a Moog ladder
              filter, but using diodes instead of BJTs for the active component of
              the filter.
    - Sequencer: a small bank of memory and logic that generates the frequencies to be
    produced by the oscillator.
    - VCA: a voltage controlled amplifier used to control the dynamics (volume before,      
    during, and after a note is played). The TB-303 has the controls of ADSR
    (attack, delay, sustain, and release).

Thus, the Hardware 303 should implement the digital equivalent of each of these blocks.
That is,

    - A numerically controlled oscillator that takes an integer and produces both a square
    and sawtooth wave of the desired frequency.
    - A Moog ladder filter that models the dynamics of the analog filter.
    - A sequencer that generates integers according to a user input pattern.
    - A NCA (numerically controlled amplifier) that prescales the output according
      to the desired settting.

<insert picture of ADSR here>
<insert picture of blocks>
<insert schematic of TB-303 ???>

In this project, an NCO and filter were implemented and tested in VHDL.

### NCO

An NCO capable of outputting a square and sawtooth wave essentially consists of
an adder, a comparator, and a few registers to accumualte the added value. The
input word is added each clock period, and if a sawtooth waveform is desired,
we just output the accumulated value. If a square wave output is desired, we
simply threshold the accumulated value according to our desired duty cycle. More
complex NCOs included phase control word inputs in addition to frequency control
inputs, allowing the user to shift the phase when desired. If a sine wave is
desired, a lookup table mapping an accumulated value to an output value can be
implemented.

The NCO was tested over the bass clef range by logging the output word at each
clock cycle to a text file. This text file was then analyzed with a Python
script, `verify_nco.py`. This generates both a time and frequency domain plot
for each output frequency. We also programmitically verify that besides just the
fundamental frequency being correct, the spectral contents of the waveform
are what we expect for a square and sawtooth wave. A perfect square wave will
contain only odd harmonics, while a sawtooth wave will include all harmonics.
The harmonics of both will decay at a rate of 6dB / octave. 

### Filter

A resonant low-pass filter is simply a low-pass filter that produces 
The filter is based on the Huovilainen's paper titled "NON-LINEAR DIGITAL
IMPLEMENTATION OF THE MOOG LADDER FILTER" [1], in which the author aproximates
the non-linearities of a Moog ladder filter, resulting in the following
input-output equations:


$$
\begin{aligned}
y_a(n) &= y_a(n-1) + \frac{I_{ctl}}{CF_s}\left(\tanh\left(\frac{x(n) - 4ry_d(n-1)}{2V_t}\right) - W_a(n-1)\right) \\[10pt]
y_b(n) &= y_b(n-1) + \frac{I_{ctl}}{CF_s}\left(W_a(n) - W_b(n-1)\right) \\[10pt]
y_c(n) &= y_c(n-1) + \frac{I_{ctl}}{CF_s}\left(W_b(n) - W_c(n-1)\right) \\[10pt]
y_d(n) &= y_d(n-1) + \frac{I_{ctl}}{CF_s}\left(W_c(n) - \tanh\left(\frac{y_d(n-1)}{2V_t}\right)\right) \\[10pt]
W_{\{a,b,c\}}(n) &= \tanh\left(\frac{y_{\{a,b,c\}}(n)}{2V_t}\right)
\end{aligned}
$$


where $x[n]$ is the output of NCO, and $y_d$ is the output of the filter. We naturally
see that this design lends itself to a multistage design, in which we can generically
define a filter stage, as well as a generic "W block" that computes  $W_{\{a,b,c\}}(n)$.

The W block can be represented as follows:

![W block diagram](w_block.jpg)

Pratically, we implement division and mulitplication with the CORDIC as well.
Aditionally, since the CORDIC can only calculate sinh, and cosh, we need a final
division step to calculate tanh. This can be done with the following arrangement
of CORDICs:


![W block digital diagram](w_block_digital.jpg)


It is important to note that the finished design uses Q1.14 signed fixed point
numbers (or Q2.14 depending on the naming) convention. This means that we have
two bits for a signed integer part, and 14 bits for the fractional part. This
was done because the CORDIC was rigorously tested in this configuration, but
this severely limits range of intermediate values we can represent. Ideally,
we would be able to represent the voltage range of original TB-303, which is
most on the order of 10s of voltages.

## Results

[1] https://dafx.de/paper-archive/2004/P_061.PDF
